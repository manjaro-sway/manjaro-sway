import z from "zod";
import type { Env } from "../../utils";
import acceptLanguage from "accept-language";

const supportedLocales = ["en", "de"] as const;

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

type WWOCode =
  | 0
  | 1
  | 2
  | 3
  | 45
  | 48
  | 51
  | 53
  | 55
  | 56
  | 57
  | 61
  | 63
  | 65
  | 66
  | 67
  | 71
  | 73
  | 75
  | 77
  | 80
  | 81
  | 82
  | 85
  | 86
  | 95
  | 96
  | 99;

const wmoCodeToEmojiMap: Record<WWOCode, string> = {
  0: "☀️", // Clear sky
  1: "🌤️", // Mainly clear
  2: "⛅", // Partly cloudy
  3: "☁️", // Overcast
  45: "🌫️", // Fog
  48: "🌫️", // Depositing rime fog
  51: "🌧️", // Drizzle: Light intensity
  53: "🌧️", // Drizzle: Moderate intensity
  55: "🌧️", // Drizzle: Dense intensity
  56: "🌧️", // Freezing Drizzle: Light intensity
  57: "🌧️", // Freezing Drizzle: Dense intensity
  61: "🌧️", // Rain: Slight intensity
  63: "🌧️", // Rain: Moderate intensity
  65: "🌧️", // Rain: Heavy intensity
  66: "🌧️", // Freezing Rain: Light intensity
  67: "🌧️", // Freezing Rain: Heavy intensity
  71: "❄️", // Snow fall: Slight intensity
  73: "❄️", // Snow fall: Moderate intensity
  75: "❄️", // Snow fall: Heavy intensity
  77: "❄️", // Snow grains
  80: "🌧️", // Rain showers: Slight intensity
  81: "🌧️", // Rain showers: Moderate intensity
  82: "🌧️", // Rain showers: Violent intensity
  85: "❄️", // Snow showers: Slight intensity
  86: "❄️", // Snow showers: Heavy intensity
  95: "⛈️", // Thunderstorm: Slight or moderate
  96: "⛈️", // Thunderstorm with slight hail
  99: "⛈️", // Thunderstorm with heavy hail
};

type WMOTranslation = Record<WWOCode, string>;

const wmoCodeToText: Record<(typeof supportedLocales)[number], WMOTranslation> =
  {
    en: {
      0: "Clear sky",
      1: "Mainly clear",
      2: "Partly cloudy",
      3: "Overcast",
      45: "Fog",
      48: "Depositing rime fog",
      51: "Light drizzle",
      53: "Moderate drizzle",
      55: "Dense drizzle",
      56: "Light freezing drizzle",
      57: "Dense freezing drizzle",
      61: "Slight rain",
      63: "Moderate rain",
      65: "Heavy rain",
      66: "Light freezing rain",
      67: "Heavy freezing rain",
      71: "Slight snow fall",
      73: "Moderate snow fall",
      75: "Heavy snow fall",
      77: "Snow grains",
      80: "Slight rain showers",
      81: "Moderate rain showers",
      82: "Violent rain showers",
      85: "Slight snow showers",
      86: "Heavy snow showers",
      95: "Slight or moderate thunderstorm",
      96: "Thunderstorm with slight hail",
      99: "Thunderstorm with heavy hail",
    },
    de: {
      0: "Klarer Himmel",
      1: "Überwiegend klar",
      2: "Teilweise bewölkt",
      3: "Bedeckt",
      45: "Nebel",
      48: "Rauhreifnebel",
      51: "Leichter Nieselregen",
      53: "Mäßiger Nieselregen",
      55: "Dichter Nieselregen",
      56: "Leichter gefrierender Nieselregen",
      57: "Dichter gefrierender Nieselregen",
      61: "Leichter Regen",
      63: "Mäßiger Regen",
      65: "Starker Regen",
      66: "Leichter gefrierender Regen",
      67: "Starker gefrierender Regen",
      71: "Leichter Schneefall",
      73: "Mäßiger Schneefall",
      75: "Starker Schneefall",
      77: "Schneekörner",
      80: "Leichte Regenschauer",
      81: "Mäßige Regenschauer",
      82: "Heftige Regenschauer",
      85: "Leichte Schneeschauer",
      86: "Starke Schneeschauer",
      95: "Leichtes oder mäßiges Gewitter",
      96: "Gewitter mit leichtem Hagel",
      99: "Gewitter mit starkem Hagel",
    },
  };

acceptLanguage.languages([...supportedLocales]);

const translations = {
  en: {
    feels_like: "Feels like",
    wind: "Wind",
    humidity: "Humidity",
    today: "Today",
    tomorrow: "Tomorrow",
  },
  de: {
    feels_like: "Gefühlt",
    wind: "Wind",
    humidity: "Luftfeuchtigkeit",
    today: "Heute",
    tomorrow: "Morgen",
  },
};

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

  let { longitude, latitude, city, country } = context.request.cf;

  // If the location is set to "auto" and the language is not English, we need to get the coordinates of the city
  // Otherwise we trust the geo-ip data from Cloudflare
  if (location === "auto" && language !== "en") {
    try {
      const locationResponse = await fetch(
        `https://geocoding-api.open-meteo.com/v1/search?name=${
          location === "auto" ? `${city}, ${country}` : location
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
    daily: "weather_code,apparent_temperature_min,apparent_temperature_max",
    forecast_days: "3",
    forecast_hours: "72",
    ...input.data,
  };

  const searchParams = new URLSearchParams();

  for (const [key, value] of Object.entries(query)) {
    searchParams.append(key, value);
  }

  const response = await fetch(
    `https://api.open-meteo.com/v1/forecast?${searchParams.toString()}`,
    {
      cf: {
        cacheTtl: 60 * 30,
      },
    }
  );

  const result = await response.json<{
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
    };
    daily: {
      time: string[];
      apparent_temperature_min: number[];
      apparent_temperature_max: number[];
      weather_code: number[];
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

  const dailies = result.daily.time.map((_, index) => {
    return [
      `<b>${result.daily.time[index]}</b> - ${
        wmoCodeToText[language][result.daily.weather_code[index]]
      } ${wmoCodeToEmojiMap[result.daily.weather_code[index]]} - ${
        result.daily.apparent_temperature_min[index]
      }${result.daily_units.apparent_temperature_min}/${
        result.daily.apparent_temperature_max[index]
      }${result.daily_units.apparent_temperature_max}`,
    ].join("\n");
  });

  return Response.json(
    {
      text: `${result.current.temperature_2m}${result.current_units.temperature_2m}`,
      alt: `${result.current.weather_code}`,
      tooltip: lines.join("\n") + "\n\n" + dailies.join("\n"),
    },
    {
      headers: {
        "content-type": "application/json",
      },
    }
  );
};
