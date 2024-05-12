import type { Env } from "./types";

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
        city
    } = context.request.cf;

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
        city
    }, {
        headers: {
            "content-type": "application/json",
        },
    });
};
