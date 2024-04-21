import { type Env } from "../utils";

const numberFormat = new Intl.NumberFormat("en-US");

export const onRequest: PagesFunction<Env> = async (context) => {
	let cache = caches.default;
	const cachedResponse = await cache.match(context.request);
  
	if (cachedResponse) {
	  console.log("Cache hit");
	  return cachedResponse;
	}

	const total = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT SUM(count) as sum FROM downloads;"
	).first<number>('sum');
	const today = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT count FROM downloads WHERE timestamp = CURRENT_DATE;"
	).first<number>('count');
	const weekly_avg = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT AVG(count) as weekly_avg FROM (SELECT SUM(count) as count FROM downloads WHERE timestamp <= date('now', 'weekday 0', '-1 day') and timestamp > '2023-02-15' GROUP BY STRFTIME('%Y-%W', timestamp));"
	).first<number>('weekly_avg');
	const weekly_sum = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT SUM(count) as weekly_sum FROM downloads WHERE timestamp > (SELECT DATETIME('now', '-7 day'));"
	).first<number>('weekly_sum');

	const response = new Response(JSON.stringify({
		total: numberFormat.format(total),
		today: numberFormat.format(today),
		weekly_avg: numberFormat.format(weekly_avg),
		weekly_sum: numberFormat.format(weekly_sum),
	}), {
		headers: {
			"content-type": "application/json",
			expires: new Date(Date.now() + 1000 * 60 * 60).toUTCString(),
		}
	});

	cache.put(context.request, response.clone());

	return response;
}
