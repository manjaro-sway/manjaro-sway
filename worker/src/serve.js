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
 * The landing page's design language, so /iso and /packages read as parts
 * of the same site rather than as a file server bolted to it: #282828
 * page, #141a1b topbar, #eee foreground, #16a085 accent, the logo
 * watermark, monospace for anything a reader might copy.
 *
 * docs/index.html carries its own copy of these rules. Two copies, because
 * the page is a static asset the worker never renders and this is a string
 * the worker returns - there is no build step to share them through, and a
 * stylesheet request would be a second round trip for ~1 KB.
 */
const STYLE = `
* { color: #eee; text-decoration: none; }
body {
  background-repeat: no-repeat;
  background-attachment: fixed;
  background-size: cover;
  background-position: center right;
  background-image: url("/img/background.svg");
  background-color: #282828;
  margin: 0;
  font-family: Roboto, Helvetica, Arial, sans-serif;
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}
header { background: #141a1b; height: 30px; }
h1 {
  color: #16a085;
  font-size: 0.8rem;
  font-weight: 500;
  line-height: 30px;
  padding: 0 20px;
  margin: 0;
}
h1 a.home { color: #8a8f98; }
h1 a.home:hover { color: #16a085; }
/* The watermark is decoration; a listing is a long dense table, and over
   the logo's light areas the dimmed size and date columns stopped being
   readable. A panel behind the content keeps the artwork visible around it
   and the text legible on it. The landing page needs none of this: its
   content is a few short paragraphs that end above the logo.
   The background is sized to cover, because the svg paints its own canvas
   and any smaller size shows that rectangle's edge. */
main {
  margin: 20px;
  padding: 4px 20px 20px;
  background: rgba(40, 40, 40, 0.82);
  border-radius: 3px;
  /* A flex item sizes to its content, and a package filename is ~45
     monospace characters that will not wrap - so the panel itself grew
     past the viewport and took the page with it, which no overflow rule
     on the table inside could undo. Bound the width to what is actually
     available and let the table scroll within it. min-width: 0 because a
     flex item's automatic minimum size is its content, which silently
     defeats the max-width above it. */
  /* vw, not %: a percentage resolves against the flex container, which has
     already grown to fit this item, so it bounds nothing. The viewport is
     the one width that does not move. */
  width: min(60rem, 100vw - 40px);
  /* border-box, or the padding is added to that width: the panel came out
     at exactly the viewport width, its own margins pushed off the screen,
     and the page scrolled sideways by the padding. */
  box-sizing: border-box;
  min-width: 0;
  align-self: flex-start;
}
h2 {
  color: #16a085;
  font-size: 0.8rem;
  font-weight: 500;
  margin: 2rem 0 0.4rem;
}
table { border-collapse: collapse; font-family: monospace; }
td { padding: 2px 20px 2px 0; white-space: nowrap; }
td:not(:first-child) { color: #8a8f98; }
/* A package filename is ~45 monospace characters and does not wrap, so on
   a phone it pushed the size and date columns off the panel entirely.
   Scroll the table rather than the page: the columns stay aligned and
   reachable, and nothing else on the page moves sideways. */
.listing { overflow-x: auto; }
@media (max-width: 40rem) {
  main { margin: 10px; padding: 4px 10px 10px; width: min(60rem, 100vw - 20px); }
  td { padding-right: 12px; }
  /* On a phone the table is wider than any viewport, and a horizontal
     scroll inside a panel is a gesture nobody discovers - the rows just
     look cut off. Stack each row instead: the filename wraps in full, and
     its size and date sit under it as one dimmed line. */
  .listing table, .listing tbody, .listing tr, .listing td { display: block; }
  .listing tr {
    padding: 0.3rem 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }
  .listing td,
  .listing td a {
    padding: 0;
    white-space: normal;
    overflow-wrap: anywhere;
  }
  /* block, not inline-block: an inline-block shrink-wraps to its longest
     unbreakable run, so a name whose last break opportunity falls before
     the panel edge still overhung it. As a block it is bound by the cell
     and overflow-wrap can break anywhere it must. */
  .listing td a { display: block; }
  /* size and date, side by side under the name rather than one per line.
     :empty guards the parent and directory rows, whose size and date cells
     are blank - without it they render a bare separator dot. */
  .listing td:not(:first-child) { display: inline; font-size: 0.85em; }
  .listing td:empty { display: none; }
  .listing td:nth-child(2):not(:empty)::after { content: " · "; }
}
/* the same text-shadow the landing page gives its links: the watermark
   runs behind this text, and monospace on a mid-tone edge is where it
   first becomes hard to read */
table a, .row { text-shadow: 2px 2px #282828; }
.row {
  display: flex;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.15rem 0;
  font-family: monospace;
}
a:hover, .row:hover { color: #16a085; }
p { color: #8a8f98; font-size: 0.85rem; line-height: 1.6; }
code { font-family: monospace; color: #16a085; }
/* the landing page's inline link: monospace and lifted off the watermark.
   The markup already used it; nothing here defined it, so it rendered as
   undecorated body text. The colour is stated on the element rather than
   inherited: the universal selector above has the same specificity and
   wins on order, which left this the one accent link still white. */
a.link { font-family: monospace; color: #16a085; text-shadow: 2px 2px #282828; }
a.link:hover { color: #c9ccd1; }
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
    <header>
      <h1><a class="home" href="/">Manjaro Sway Edition</a> / ${escapeHtml(title)}</h1>
    </header>
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
  // ctx for waitUntil: both callers already pass it, so the cache write
  // below can outlive the response rather than delaying it
  return async (request, env, ctx) => {
    const url = new URL(request.url);
    const requested = decodeURIComponent(url.pathname.slice(1));
    const bucket = env[site.bucket];

    // Routes are checked before the method gate: a bucket only ever
    // answers GET and HEAD, but a route may be a POST endpoint, and
    // rejecting it here would make the route unreachable rather than
    // wrong - which is how the score endpoint first answered 405.
    //
    // (request, bucket, env, url) rather than just the bucket: the stats
    // routes need env for the analytics binding and the query for the
    // version filter. One signature covering all of them beats each
    // adding its own parameter.
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
      // A pointer is a version string - twelve bytes or so. Reading the
      // body without checking its size kills the isolate if the key ever
      // holds an image instead: text() on gigabytes is Cloudflare's error
      // 1101, and the alias answers 500 until the object is replaced.
      // Anything larger than a version cannot be one, so it is not read.
      if (pointer.size > 64) return notFound();
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

    // An immutable object is redirected to the bucket's own hostname
    // instead of being streamed through here. run_worker_first means this
    // worker is invoked for every request on every route, so serving the
    // bytes ourselves spends an invocation per request - 87.5k in a day,
    // 77% of the free tier - on objects that never change. The CDN
    // hostname has no worker in front of it: the redirect costs one
    // invocation per file, and the transfer and every repeat fetch cost
    // none.
    //
    // Only what the site marks immutable. The database and the signatures
    // beside it are rewritten in place on every publish, and pointing a
    // client at a cacheable copy of either is how a reader ends up with a
    // package that does not match the signature it just fetched.
    //
    // A range or conditional request is not redirected: those resume a
    // download or revalidate, the client already holds a validator from
    // this host, and a hop mid-resume is a splice risk for no saving.
    const direct = site.direct?.(key);
    if (
      direct &&
      request.method === 'GET' &&
      !request.headers.get('range') &&
      !request.headers.get('if-range') &&
      !request.headers.get('if-none-match')
    ) {
      // head first: without it an absent package answers 302 to a URL that
      // is also absent, so a typo or a pruned version becomes a redirect
      // into a 404 on another host rather than an honest 404 here. One
      // metadata read, against a transfer this hands off entirely.
      if (!(await bucket.head(key))) return notFound();
      const hop = new Response(null, {
        status: 302,
        headers: {
          location: direct,
          // the object is immutable, so the hop to it is too - but keep it
          // short enough that moving the bucket is not a year-long wait
          'cache-control': 'public, max-age=3600',
        },
      });
      // the last point at which this download is visible to us: the bytes
      // move on a host that reports nothing back
      site.record?.(env, key, hop.status, request.method);
      return hop;
    }

    const response = await serveObject(request, bucket, key, site.headers(key));
    // after the response, because only its status says whether anything was
    // transferred. Optional and site-specific: the packages site defines no
    // record, so pacman traffic is never counted.
    site.record?.(env, key, response.status, request.method);
    return response;
  };
}
