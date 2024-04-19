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
	const currentDay = await context.env.VISITOR_COUNT_STORE.prepare(
		"SELECT count FROM downloads WHERE timestamp = CURRENT_DATE;"
	).first<number>('count');

	const response = new Response(JSON.stringify({
		total: numberFormat.format(total),
		currentDay: numberFormat.format(currentDay)
	}), {
		headers: {
			"content-type": "application/json",
			expires: new Date(Date.now() + 1000 * 60 * 60).toUTCString(),
		}
	});

	cache.put(context.request, response.clone());

	return response;
}
