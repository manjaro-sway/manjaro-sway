import { Env, getCount } from "../utils";

const numberFormat = new Intl.NumberFormat("en-US");

export const onRequest: PagesFunction<Env> = async (context) => {
	const value = await getCount(context);
	const response = new Response(JSON.stringify({ count: numberFormat.format(value) }));
	response.headers.set(
		'Cache-Control',
		's-maxage=86400, stale-while-revalidate',
	);
	response.headers.set('Content-Type', 'application/json');

	return response;
}
