import z from "zod";
import type { Env } from "../types";
import acceptLanguage from "accept-language";
import { supportedLocales, wmoCodeToEmojiMap, wmoCodeToText } from "./utils";

const inputValidator = z.object({
  temperature_unit: z
    .enum(["fahrenheit", "celsius"])
    .optional()
    .default("celsius"),
  wind_speed_unit: z.enum(["mph", "kmh"]).optional().default("kmh"),
  precipitation_unit: z.enum(["mm", "inch"]).optional().default("mm"),
  timezone: z.string().optional().default("auto"),
  language: z.enum(supportedLocales).optional(),
});

acceptLanguage.languages([...supportedLocales]);

const translations = {
  en: {
    feels_like: "Feels like",
    wind: "Wind",
    humidity: "Humidity"
  },
  de: {
    feels_like: "Gefühlt",
    wind: "Wind",
    humidity: "Luftfeuchtigkeit"
  },
  fr: {
    feels_like: "Ressenti",
    wind: "Vent",
    humidity: "Humidité"
  },
};

const uvIndexEmoji = {
  3: "😎",
  4: "😎",
  5: "😎",
  6: "🫠",
  7: "🫠",
  8: "🥵",
  9: "🥵",
  10: "🥵",
  11: "🥵",
}

export const onRequest: PagesFunction<Env> = async (context) => {
  // location parameter passed by the user (or "auto" if the user wants to use their current location based on the IP address)
  const location = context.params.location;
  const url = new URL(context.request.url);
  const input = inputValidator.safeParse(
    Object.fromEntries(url.searchParams.entries())
  );
  if (!input.success) {
    return Response.json(
      {
        error: input.error.errors,
      },
      {
        status: 400,
      }
    );
  }

  // Get the language from the user input, the Accept-Language header, or default to English
  const language =
    input.data.language ??
    (acceptLanguage.get(
      context.request.headers.get("accept-language")
    ) as (typeof supportedLocales)[number]) ??
    "en";

  const cacheUrl = new URL(context.request.url);
  cacheUrl.searchParams.set("language", language);
  cacheUrl.searchParams.set("version", "1");
  const cacheKey = new Request(cacheUrl.toString(), context.request);
  const cache = caches.default;
  const cachedResponse = await cache.match(cacheKey);

  if (cachedResponse) {
    console.log("Cache hit");
    return cachedResponse;
  }

  let { longitude, latitude, city } = context.request.cf;

  // If the location is not set to "auto" or the language is not English, we need to get the coordinates of the city
  // Otherwise we trust the geo-ip data from Cloudflare
  if (location !== "auto" || language !== "en") {
    try {
      const locationResponse = await fetch(
        `https://geocoding-api.open-meteo.com/v1/search?name=${
          location === "auto" ? city : location
        }&count=1&language=${language}`,
        {
          cf: {
            // Cache the response for 30 * 24 hours, as the location of a city is unlikely to change in coordinates
            cacheTtl: 60 * 60 * 24 * 30,
          },
        }
      );
      const locationResult = await locationResponse.json<{
        results: { latitude: number; longitude: number; name: string }[];
      }>();

      longitude = locationResult.results[0].longitude.toString();
      latitude = locationResult.results[0].latitude.toString();
      city = locationResult.results[0].name;
    } catch (error) {
      return Response.json(
        {
          error: JSON.stringify(error),
        },
        {
          status: 404,
        }
      );
    }
  }

  const query = {
    latitude,
    longitude,
    language,
    current:
      "temperature_2m,wind_speed_10m,weather_code,apparent_temperature,relative_humidity_2m",
    daily: "weather_code,apparent_temperature_min,apparent_temperature_max,uv_index_clear_sky_max",
    hourly:
      "apparent_temperature,weather_code,precipitation_probability",
    forecast_days: "3",
    forecast_hours: "72",
    ...input.data,
  };

  const searchParams = new URLSearchParams();

  for (const [key, value] of Object.entries(query)) {
    searchParams.append(key, value);
  }

  const weatherRequest = await fetch(
    `https://api.open-meteo.com/v1/forecast?${searchParams.toString()}`,
    {
      cf: {
        cacheTtl: 60 * 30,
      },
    }
  );

  const result = await weatherRequest.json<{
    current_units: {
      time: string;
      temperature_2m: string;
      wind_speed_10m: string;
      weather_code: string;
      apparent_temperature: string;
      relative_humidity_2m: string;
    };
    current: {
      time: string;
      temperature_2m: number;
      wind_speed_10m: 4;
      weather_code: number;
      apparent_temperature: number;
      relative_humidity_2m: number;
    };
    daily_units: {
      apparent_temperature_min: string;
      apparent_temperature_max: string;
      weather_code: string;
      time: string;
      uv_index_clear_sky_max: string;
    };
    daily: {
      time: string[];
      apparent_temperature_min: number[];
      apparent_temperature_max: number[];
      weather_code: number[];
      uv_index_clear_sky_max: number[];
    };
    hourly_units: {
      time: string;
      apparent_temperature: string;
      weather_code: string;
      precipitation_probability: string;
    };
    hourly: {
      time: string[];
      apparent_temperature: number[];
      weather_code: number[];
      precipitation_probability: number[];
    };
  }>();

  const lines = [
    `<b>${city}</b>:`,
    `<b>${wmoCodeToText[language][result.current.weather_code]} ${
      wmoCodeToEmojiMap[result.current.weather_code]
    }</b>`,
    `${translations[language].feels_like}: ${result.current.apparent_temperature}${result.current_units.apparent_temperature}`,
    `${translations[language].wind}: ${result.current.wind_speed_10m}${result.current_units.wind_speed_10m}`,
    `${translations[language].humidity}: ${result.current.relative_humidity_2m}${result.current_units.relative_humidity_2m}`,
  ];

  const hourlies = result.hourly.time
    .map((_, index) => {
      const time = result.hourly.time[index];
      const temperature = result.hourly.apparent_temperature[index];
      const weatherCode = result.hourly.weather_code[index];
      const hour = new Date(time).getHours();
      const precipitation_probability =
        result.hourly.precipitation_probability[index];

      return {
        time,
        temperature,
        weatherCode,
        hour,
        precipitation_probability,
      };
    })
    .filter((hourly) => hourly.hour % 2 === 0);

  const dailies = result.daily.time.map((_, index) => {
    const currentHours = hourlies.filter((hourly) =>
      hourly.time.startsWith(result.daily.time[index])
    );
    return [
      `<b>${result.daily.time[index]}</b> - ${
        wmoCodeToText[language][result.daily.weather_code[index]]
      } ${wmoCodeToEmojiMap[result.daily.weather_code[index]]}`,
      `⬇️${
        result.daily.apparent_temperature_min[index]
      }${result.daily_units.apparent_temperature_min} ⬆️${
        result.daily.apparent_temperature_max[index]
      }${result.daily_units.apparent_temperature_max}${
        result.daily.uv_index_clear_sky_max[index] >=6 ? ` ${uvIndexEmoji[Math.round(result.daily.uv_index_clear_sky_max[index])]}${
          result.daily.uv_index_clear_sky_max[index]} UV Index` : ""}`,
      ...currentHours.map((hourly) => {
        return `${hourly.hour}: ${hourly.temperature}${
          result.hourly_units.apparent_temperature
        } ${wmoCodeToText[language][hourly.weatherCode]} ${
          wmoCodeToEmojiMap[hourly.weatherCode]
        }${
          hourly.precipitation_probability > 0
            ? ` ☔${hourly.precipitation_probability}%`
            : ""
        }`;
      }),
    ].join("\n");
  });

  const response = Response.json(
    {
      text: `${result.current.temperature_2m}${result.current_units.temperature_2m}`,
      alt: `${result.current.weather_code}`,
      tooltip: `${lines.join("\n")}\n\n${dailies.join("\n\n")}\n\nPowered by Open-Meteo.com`,
    },
    {
      headers: {
        "content-type": "application/json",
        expires: new Date(Date.now() + 1000 * 60 * 30).toUTCString(),
      },
    }
  );

  cache.put(context.request, response.clone());

  return response;
};
