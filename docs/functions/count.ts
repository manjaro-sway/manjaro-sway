import { Env, getCount } from "../utils";

const numberFormat = new Intl.NumberFormat("en-US");

export const onRequest: PagesFunction<Env> = async (context) => {
	const value = await getCount(context);

	const dayBeforeCount = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT count FROM visitor_statistics WHERE timestamp = DATE(CURRENT_DATE, '-1 day');"
	).first<number>('count');
	const gain = value - dayBeforeCount;

	await context.env.VISITOR_COUNT_STORE.prepare(
		"INSERT OR REPLACE INTO visitor_statistics (count, gain) VALUES (?, ?);"
	).bind(value, gain).run();

	const weeklyAverage = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT AVG(gain) as weekly FROM (SELECT SUM(gain) as gain FROM visitor_statistics WHERE timestamp > (SELECT DATETIME('now', '-7 day')) GROUP BY STRFTIME('%Y-%W', timestamp));"
	).first<number>('weekly');

	const sevenDays = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT SUM(gain) as sum FROM visitor_statistics WHERE timestamp > (SELECT DATETIME('now', '-7 day'));"
	).first<number>('sum');

	const response = new Response(JSON.stringify({
		count: numberFormat.format(value),
		currentDay: numberFormat.format(gain),
		weeklyAverage: numberFormat.format(Math.round(weeklyAverage)),
		sevenDays: numberFormat.format(sevenDays)
	}));

	response.headers.set(
		'Cache-Control',
		's-maxage=86400, stale-while-revalidate',
	);
	response.headers.set('Content-Type', 'application/json');

	return response;
}
