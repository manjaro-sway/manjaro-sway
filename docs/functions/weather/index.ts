import type { Env } from "../types";

export const onRequest: PagesFunction<Env> = async (context) => {
    const url = new URL(context.request.url);
    url.pathname = `/weather/${context.request.cf.city}`;
    return Response.redirect(url.toString(), 307);
};
