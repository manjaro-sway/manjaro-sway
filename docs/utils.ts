export type Env = {
  KV: KVNamespace;
  VISITOR_COUNT_STORE: D1Database;
  ANALYTICS_ENGINE: AnalyticsEngineDataset;
};
type Context = EventContext<Env, any, Record<string, unknown>>;

export const getCount = async (context: Context) => {
  const value = await context.env.KV.get("count");
  return Number.parseInt(value);
};

export const countUp = async (context: Context) => {
  const current = await getCount(context);
  await context.env.KV.put("count", (current + 1).toString());
  return current + 1;
};
