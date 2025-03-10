import type { Env } from "./types";
import { getSunrise, getSunset } from 'sunrise-sunset-js';
import dayjs from 'dayjs';
import utc from 'dayjs/plugin/utc';
import timezone from 'dayjs/plugin/timezone';

dayjs.extend(utc)
dayjs.extend(timezone)


export const onRequest: PagesFunction<Env> = async (context) => {
    const {
        longitude,
        continent,
        country,
        isEUCountry,
        colo,
        timezone,
        region,
        regionCode,
        latitude,
        postalCode,
        city,
    } = context.request.cf;

    const tomorrow = dayjs().add(1, 'day').tz(timezone).toDate();

    return Response.json({
        longitude,
        continent,
        country,
        isEUCountry,
        colo,
        timezone,
        region,
        regionCode,
        latitude,
        postalCode,
        city,
        sunrise: getSunrise(Number(latitude), Number(longitude)),
        sunset: getSunset(Number(latitude), Number(longitude)),
        sunrise_tomorrow: getSunrise(Number(latitude), Number(longitude), tomorrow),
        sunset_tomorrow: getSunset(Number(latitude), Number(longitude), tomorrow),
    }, {
        headers: {
            "content-type": "application/json",
        },
    });
};
