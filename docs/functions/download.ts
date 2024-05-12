import type { Env } from "./types";

const hostname = "mirror.manjaro-sway.download";

export const onRequest: PagesFunction<Env> = async (context) => {
  const url = new URL(context.request.url);

  url.hostname = hostname;
  url.pathname = `manjaro-sway/${url.searchParams.get("file")}`;
  url.searchParams.forEach((_value, name) => url.searchParams.delete(name));

  if (context.request.method === "GET") {
    if (url.pathname.endsWith(".iso") || url.pathname.endsWith(".xz")) {
      await context.env.VISITOR_COUNT_STORE.prepare(
        "INSERT OR IGNORE INTO downloads (count) VALUES (1);"
      ).run();
      await context.env.VISITOR_COUNT_STORE.prepare(
        "UPDATE downloads SET count=(count+1) WHERE timestamp = CURRENT_DATE;"
      ).run();
    }
  }

  return Response.redirect(url.toString(), 301);
};
