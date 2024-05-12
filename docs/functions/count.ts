import type { Env } from "./types";

const numberFormat = new Intl.NumberFormat("en-US");

export const onRequest: PagesFunction<Env> = async (context) => {
	const cache = caches.default;
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
	const best_day = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT MAX(count) as best_day FROM downloads WHERE timestamp > '2023-02-15';"
	).first<number>('best_day');
	const worst_day = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT MIN(count) as worst_day FROM downloads WHERE timestamp > '2023-02-15';"
	).first<number>('worst_day');

	const response = new Response(JSON.stringify({
		total: numberFormat.format(total),
		today: numberFormat.format(today),
		weekly_avg: numberFormat.format(Math.floor(weekly_avg)),
		weekly_sum: numberFormat.format(Math.floor(weekly_sum)),
		best_day: numberFormat.format(best_day),
		worst_day: numberFormat.format(worst_day)
	}), {
		headers: {
			"content-type": "application/json",
			expires: new Date(Date.now() + 1000 * 60 * 60).toUTCString(),
		}
	});

	cache.put(context.request, response.clone());

	return response;
}
