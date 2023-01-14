interface Env {
	KV: KVNamespace;
}

const numberFormat = new Intl.NumberFormat("en-US");
const baseArgs = {
	owner: "manjaro-sway",
	repo: "manjaro-sway"
}

const github = (path: string) => {
	return fetch(`https://api.github.com/${path.replace('{ower}', baseArgs.owner).replace('{repo}', baseArgs.repo)}`, {
		headers: {
			"Authorization": `Bearer ${process.env.GITHUB_PAT}`
		}
	})
}

export const onRequest: PagesFunction<Env> = async (context) => {
	const counterResponse = await fetch("https://api.numeri.xyz/v1/3bc55102-fe06-4648-a6b3-4083a00efae8", {
		cf: {
			cacheTtl: 1,
			cacheEverything: true,
		},
	}).then(response => response.json());

	const repo = await github('/repos/{owmer}/{repo}/releases/202301080256');

	const result = Number.parseInt(counterResponse as string);
	const response = new Response(JSON.stringify({ count: numberFormat.format(result), repo }));
	response.headers.set(
		'Cache-Control',
		's-maxage=86400, stale-while-revalidate',
	);
	response.headers.set('Content-Type', 'application/json');

	return response;
}
