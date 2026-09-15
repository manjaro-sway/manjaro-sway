/**
 * What serving a bucket over HTTP has in common, whichever bucket it is.
 *
 * R2 has no directories: a listing is a delimited list() over the key
 * prefix. Object reads stream straight through, so a client gets plain
 * bytes with working range requests.
 */

export const escapeHtml = (s) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

export function humanSize(bytes) {
  const units = ['B', 'KiB', 'MiB', 'GiB'];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${unit === 0 ? value : value.toFixed(1)} ${units[unit]}`;
}

/**
 * The design language from sway-repo/_layouts/default.html, with the
 * Manjaro green replaced by our stone accent. Both sites render with it,
 * which is the point of having one worker.
 */
const STYLE = `
* { color: #eee; text-decoration: none; }
body {
  background: #282828;
  margin: 0;
  font-family: Roboto, Helvetica, Arial, sans-serif;
}
h1 {
  background: #141a1b;
  color: #8a8f98;
  font-size: 0.8rem;
  font-weight: 500;
  line-height: 30px;
  padding: 0 20px;
  margin: 0;
}
main { margin: 20px; max-width: 60rem; }
h2 {
  color: #8a8f98;
  font-size: 0.8rem;
  font-weight: 500;
  margin: 1.6rem 0 0.3rem;
}
/* the machine a download is for, under the version it belongs to: dimmer
   than the version and closer to the rows it labels, so the grouping reads
   as a subdivision rather than a second list */
h3 {
  color: #6b7280;
  font-size: 0.75rem;
  font-weight: 500;
  margin: 0.7rem 0 0.2rem;
}
table { border-collapse: collapse; font-family: monospace; }
td { padding: 2px 20px 2px 0; white-space: nowrap; }
td:not(:first-child) { color: #8a8f98; }
.row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.15rem 0;
  font-family: monospace;
}
a:hover, .row:hover { color: #c9ccd1; }
p { color: #8a8f98; font-size: 0.85rem; line-height: 1.6; }
code { font-family: monospace; color: #c9ccd1; }
/* width and height are on the element too: the page ships no external css,
   so a late-loading image would otherwise reflow the downloads under it */
.shots { display: flex; flex-wrap: wrap; gap: 0.6rem; margin: 1rem 0; }
/* max-width, the same thing .tour below already had: a fixed 480px on a
   390px phone put the right edge of every shot 112px past the viewport
   and scrolled the whole page sideways. aspect-ratio rather than a fixed
   height, because once the width is allowed to shrink a fixed height
   makes object-fit crop more of the picture the smaller the screen gets -
   scaling it down is what a reader wants. */
.shot {
  width: 480px;
  max-width: 100%;
  height: auto;
  aspect-ratio: 16 / 9;
  object-fit: cover;
  border: 1px solid #3a4043;
}
.tour { max-width: 100%; height: auto; border: 1px solid #3a4043; margin: 1rem 0; }
`;

export function page(title, body) {
  return `<!DOCTYPE html>
<html lang="en">
  <head>
    <title>${escapeHtml(title)}</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
    <style>${STYLE}</style>
  </head>
  <body>
    <h1>${escapeHtml(title)}</h1>
    <main>
${body}
    </main>
  </body>
</html>
`;
}

export const html = (body) =>
  new Response(body, { headers: { 'content-type': 'text/html; charset=utf-8' } });

export const json = (body, status = 200) =>
  new Response(`${JSON.stringify(body)}\n`, {
    status,
    headers: { 'content-type': 'application/json' },
  });

export const notFound = () => new Response('not found', { status: 404 });

/**
 * Stream one object, with the caching and headers the site asks for.
 *
 * Range and conditional requests are handed to R2 rather than reimplemented:
 * a resumed 1.7 GB ISO download depends on both.
 */
export async function serveObject(request, bucket, key, extraHeaders = {}) {
  // If-Range decides whether a resumed download may continue, and R2 does
  // not apply it: a stale validator still came back 206. That is the
  // dangerous answer for `latest/`, which is a real object repointed at
  // every release - a client resuming across one would splice bytes from
  // two different ISOs into a file that fails its checksum and looks like
  // a corrupt download rather than a moved target.
  //
  // So it is evaluated here: a validator that no longer matches drops the
  // range and serves the whole current object, which is what RFC 9110
  // asks for and what makes the client start over instead of stitching.
  const ifRange = request.headers.get('if-range');
  let wanted = request.headers;
  if (ifRange && request.headers.get('range')) {
    const current = await bucket.head(key);
    if (!current) return notFound();
    // an entity-tag comparison; a weak tag never matches for a range
    if (ifRange.trim() !== current.httpEtag) {
      wanted = new Headers(request.headers);
      wanted.delete('range');
    }
  }

  const object = await bucket.get(key, {
    range: wanted,
    onlyIf: request.headers,
  });
  if (!object) return notFound();

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set('etag', object.httpEtag);
  // writeHttpMetadata carries the stored content type and nothing about
  // size or ranges. curl and a browser downloading an ISO do not care; a
  // <video> element does - it probes with HEAD, finds no length and no
  // advertised range support, concludes it cannot seek, and fails the
  // load with a format error even though the bytes are perfect and a
  // range request would have been answered.
  headers.set('accept-ranges', 'bytes');
  const ranged = object.range && 'offset' in object.range;
  if (ranged) {
    const { offset, length } = object.range;
    headers.set('content-range', `bytes ${offset}-${offset + length - 1}/${object.size}`);
    headers.set('content-length', String(length));
  } else {
    headers.set('content-length', String(object.size));
  }
  for (const [name, value] of Object.entries(extraHeaders)) headers.set(name, value);

  // `ranged`, not the request header: a range dropped by the If-Range
  // check above must be answered 200 with the whole object, and saying
  // 206 there would tell the client its stale offsets were honoured.
  const status = object.body ? (ranged ? 206 : 200) : 304;
  return new Response(request.method === 'HEAD' ? null : object.body, { status, headers });
}

/**
 * Turn a site definition into a fetch handler.
 *
 * A site supplies: `bucket` (the binding name), `title`, `resolveKey`,
 * `listing`, `headers`, and optionally `routes` for anything it serves
 * that is not a bucket object. A route is called with
 * (request, bucket, env, url).
 */
export function handler(site) {
  return async (request, env) => {
    const url = new URL(request.url);
    const requested = decodeURIComponent(url.pathname.slice(1));
    const bucket = env[site.bucket];

    // Routes are checked before the method gate: a bucket only ever
    // answers GET and HEAD, but a route may be a POST endpoint, and
    // rejecting it here would make the route unreachable rather than
    // wrong - which is how the score endpoint first answered 405.
    //
    // (request, bucket, env, url) rather than just the bucket: /geo needs
    // request.cf, and the game routes need env and the query. One
    // signature covering all of them beats each adding its own parameter.
    const route = site.routes?.[requested];
    if (route) return route(request, bucket, env, url);

    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('method not allowed', { status: 405 });
    }

    const key = site.resolveKey(requested);
    if (key === null) return notFound();

    // An alias is a pointer holding a version string, not the image. It
    // is read and redirected rather than served, so a download targets an
    // immutable versioned URL: `latest/` is repointed every release, and a
    // resume across one used to ask for a byte range of an object that had
    // been replaced underneath it.
    if (site.isAlias?.(key)) {
      const pointer = await bucket.get(key);
      if (!pointer) return notFound();
      const version = (await pointer.text()).trim();
      if (!site.isVersion(version)) return notFound();
      // the object the pointer names, not a name built from a convention:
      // a constructed one is a second guess at what the builder wrote
      const target = await site.aliasTarget(bucket, version);
      if (!target) return notFound();
      return new Response(null, {
        status: 302,
        headers: {
          location: `${site.base ?? '/'}${target}`,
          // the pointer moves every release, so nothing may cache the hop
          'cache-control': 'no-cache',
        },
      });
    }

    if (site.isListing(key)) return site.listing(bucket, key);

    const response = await serveObject(request, bucket, key, site.headers(key));
    // after the response, because only its status says whether anything was
    // transferred. Optional and site-specific: the packages site defines no
    // record, so pacman traffic is never counted.
    site.record?.(env, key, response.status, request.method);
    return response;
  };
}
