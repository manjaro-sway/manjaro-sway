import { type Env } from "../utils";

const hostname = "mirror.manjaro-sway.download";

export const onRequest: PagesFunction<Env> = async (context) => {
  const url = new URL(context.request.url);

  url.hostname = hostname;
  url.pathname = `manjaro-sway/${url.searchParams.get("file")}`;
  url.searchParams.forEach((_value, name) => url.searchParams.delete(name));

  if (context.request.method === "GET") {
    context.env.ANALYTICS_ENGINE.writeDataPoint({
      indexes: [],
      blobs: [url.hostname, url.pathname],
      doubles: [],
    });

    if (url.pathname.endsWith(".iso")) {
      const currentCount = await context.env.VISITOR_COUNT_STORE.prepare(
        "SELECT count FROM downloads WHERE timestamp = CURRENT_DATE;"
      ).first<number>("gain");

      await context.env.VISITOR_COUNT_STORE.prepare(
		"INSERT OR REPLACE INTO downloads (count) VALUES (?);"
      )
        .bind((currentCount ?? 0) + 1)
        .run();
    }
  }

  return Response.redirect(url.toString(), 301);
};
