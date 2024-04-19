import { type Env, getCount } from "../utils";

const numberFormat = new Intl.NumberFormat("en-US");

export const onRequest: PagesFunction<Env> = async (context) => {
	let cache = caches.default;
	const cachedResponse = await cache.match(context.request);
  
	if (cachedResponse) {
	  console.log("Cache hit");
	  return cachedResponse;
	}

	const value = await getCount(context);

	const dayBeforeCount = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT count FROM visitor_statistics WHERE timestamp = DATE(CURRENT_DATE, '-1 day');"
	).first<number>('count');
	const gain = value - dayBeforeCount;

	await context.env.VISITOR_COUNT_STORE.prepare(
		"INSERT OR REPLACE INTO visitor_statistics (count, gain) VALUES (?, ?);"
	).bind(value, gain).run();

	const weeklyAverage = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT AVG(gain) as weekly FROM (SELECT SUM(gain) as gain FROM visitor_statistics WHERE timestamp <= date('now', 'weekday 0', '-1 day') GROUP BY STRFTIME('%Y-%W', timestamp));"
	).first<number>('weekly');

	const sevenDays = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT SUM(gain) as sum FROM visitor_statistics WHERE timestamp > (SELECT DATETIME('now', '-7 day'));"
	).first<number>('sum');

	const response = new Response(JSON.stringify({
		count: numberFormat.format(value),
		currentDay: numberFormat.format(gain),
		weeklyAverage: numberFormat.format(Math.round(weeklyAverage)),
		sevenDays: numberFormat.format(sevenDays)
	}), {
		headers: {
			"content-type": "application/json",
			expires: new Date(Date.now() + 1000 * 60 * 60).toUTCString(),
		}
	});

	cache.put(context.request, response.clone());

	return response;
}
