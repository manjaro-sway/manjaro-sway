import { Env, getCount } from "../utils";

const numberFormat = new Intl.NumberFormat("en-US");

export const onRequest: PagesFunction<Env> = async (context) => {
	const value = await getCount(context);

	await context.env.VISITOR_COUNT_STORE.prepare(
		"INSERT INTO visitor_statistics (count) VALUES (?);"
	).bind(value).run();

	const response = new Response(JSON.stringify({ count: numberFormat.format(value) }));
	response.headers.set(
		'Cache-Control',
		's-maxage=86400, stale-while-revalidate',
	);
	response.headers.set('Content-Type', 'application/json');


	return response;
}
