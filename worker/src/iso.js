/**
 * /iso - the ISO downloads.
 *
 * The listing is the bucket, not a manifest the publish job has to keep in
 * step: a page rendered from R2 cannot show an image that is not there, or
 * miss one that is.
 */

import { escapeHtml, html, humanSize, json, page } from './serve.js';
import { collect, record } from './stats.js';

// the section this page is, since the shell already names the site
const TITLE = 'images';

/** Where this site is mounted, for the links it renders. */
const BASE = '/iso/';

// The releases bucket's own custom domain. Keys are identical here to the
// ones served through the worker, so a redirect is a hostname swap.
const CDN = 'https://iso.manjaro-sway.download';


/** The alias upload_iso.py repoints at every release. */
export const ALIAS = 'latest/manjaro-sway.iso';

/**
 * The version prefix a key belongs to.
 *
 * upload_iso.py writes <version>/<name>.iso and latest/manjaro-sway.iso, so
 * the first segment is the version and `latest` is an alias rather than one.
 */
export function versionOf(key) {
  const cut = key.indexOf('/');
  return cut === -1 ? null : key.slice(0, cut);
}

export function isAlias(key) {
  return key === ALIAS;
}

export function renderIndex(byVersion) {
  // version prefixes sort chronologically, so the newest is last
  const versions = [...byVersion.keys()].sort().reverse();
  const sections = versions
    .map((version) => {
      const rows = byVersion
        .get(version)
        .map((object) => {
          const name = object.key.slice(version.length + 1);
          return (
            `<a class="row" href="${BASE}${escapeHtml(object.key)}">` +
            `<span>${escapeHtml(name)}</span>` +
            `<span>${humanSize(object.size)}</span></a>`
          );
        })
        .join('\n');
      return `<h2>${escapeHtml(version)}</h2>\n${rows}`;
    })
    .join('\n');

  return page(
    TITLE,
    `      <p>The newest ISO is always at
        <a href="${BASE}latest/manjaro-sway.iso"
          ><code>${BASE}latest/manjaro-sway.iso</code></a
        >. Verify a download against the <code>SHA256SUMS</code> beside it.
        <a class="link" href="${BASE}stats">Download stats</a>.</p>
${sections || '<p>No images published yet.</p>'}`,
  );
}

const countRow = (label, href, downloads) =>
  `<tr><td>${href ? `<a href="${href}">${escapeHtml(label)}</a>` : escapeHtml(label)}` +
  `</td><td>${downloads.toLocaleString('en-US')}</td></tr>`;

function renderStats({ configured, archive, versions, files, version }) {
  const parts = [];

  if (!configured) {
    // public page: say what is true rather than answer 500, which reads as
    // "the numbers are broken" when it means "no read token yet"
    parts.push(
      '<p>Live stats are not configured yet. Downloads are still being counted,' +
        ' and any archived months appear below.</p>',
    );
  } else {
    parts.push('<h2>Last three months</h2>');
    parts.push(
      versions.length
        ? `<table>${versions
            .map((row) =>
              countRow(
                row.version,
                `${BASE}stats?version=${encodeURIComponent(row.version)}`,
                row.downloads,
              ),
            )
            .join('')}</table>`
        : '<p>No downloads recorded yet.</p>',
    );
  }

  if (files) {
    parts.push(`<h2>${escapeHtml(version)}</h2>`);
    parts.push(
      files.length
        ? `<table>${files.map((row) => countRow(row.name, null, row.downloads)).join('')}</table>`
        : '<p>No downloads recorded for this version.</p>',
    );
  }

  for (const { month, totals } of archive) {
    const rows = Object.entries(totals).sort((a, b) => b[1] - a[1]);
    parts.push(`<h2>${escapeHtml(month)}</h2>`);
    parts.push(
      rows.length
        ? `<table>${rows.map(([name, n]) => countRow(name, null, n)).join('')}</table>`
        : '<p>No downloads that month.</p>',
    );
  }

  parts.push(
    '<p>A download is one whole-image GET that transferred.' +
      ' Resumed downloads and revalidations are not counted, and neither is' +
      ` <code>SHA256SUMS</code>. <a class="link" href="${BASE}stats.json">stats.json</a></p>`,
  );

  return page(TITLE, parts.join('\n'));
}

/**
 * What the newest release is, as JSON for the landing page.
 *
 * The page renders its download button from this rather than from a value
 * baked into the HTML at build time, which would go stale the moment a
 * release publishes and could not be noticed from the page itself.
 */
async function latest(bucket) {
  const pointer = await bucket.get(ALIAS);
  if (!pointer) return json({ error: 'nothing published yet' }, 404);
  const version = (await pointer.text()).trim();
  if (!/^\d{12}$/.test(version)) return json({ error: 'the pointer is not a version' }, 404);

  const listed = await bucket.list({ prefix: `${version}/` });
  const iso = listed.objects.find((o) => o.key.endsWith('.iso'));
  if (!iso) return json({ error: 'the release has no image' }, 404);

  // the checksum line, not the file: the page shows the hash, and making
  // the reader open a second URL to see it is how it goes unchecked
  const sums = await bucket.get(`${version}/SHA256SUMS`);
  const text = sums ? (await sums.text()).trim() : '';
  const sha256 = text.split(/\s+/)[0] ?? null;

  return json({
    version,
    name: iso.key.slice(version.length + 1),
    url: `${BASE}${iso.key}`,
    size: iso.size,
    sha256,
  });
}

export const site = {
  bucket: 'ISO',
  // where this site is mounted, for the redirect the handler builds
  base: BASE,
  isListing: (key) => key === '',

  // no arch trees here: every key is <version>/<file>, and an unknown one
  // simply misses in the bucket
  resolveKey: (path) => path,

  // latest/ holds a version string, not an image; the handler redirects
  isAlias,
  // The version a pointer may hold. A pointer that is not one is a broken
  // publish, and 404 beats redirecting somewhere arbitrary.
  isVersion: (version) => /^\d{12}$/.test(version),
  // The alias is named for the product; the real file carries the version
  // in its name. manjaro-tools names the ISO, so the target is looked up
  // rather than constructed - a built name would be a second guess at a
  // convention we do not control.
  aliasTarget: async (bucket, version) => {
    const listed = await bucket.list({ prefix: `${version}/` });
    return listed.objects.find((o) => o.key.endsWith('.iso'))?.key ?? null;
  },

  // only this site counts: every `pacman -Sy` is a database fetch, and
  // that event volume would dwarf the signal on the packages side
  record,

  routes: {
    latest: async (request, bucket) => latest(bucket),
    stats: async (request, bucket, env, url) =>
      html(renderStats(await collect(env, url.searchParams.get('version')))),
    'stats.json': async (request, bucket, env, url) =>
      json(await collect(env, url.searchParams.get('version'))),
  },

  listing: async (bucket) => {
    // Paginated, because a single list() caps at 1000 keys and answers
    // truncated without saying so. Every release adds an image and a
    // checksum, so the cap is reached by accumulation rather than by
    // anything going wrong.
    const objects = [];
    let cursor;
    do {
      const page = await bucket.list({ limit: 1000, cursor });
      objects.push(...page.objects);
      cursor = page.truncated ? page.cursor : undefined;
    } while (cursor);

    const byVersion = new Map();
    for (const object of objects) {
      const version = versionOf(object.key);
      // latest/ holds a pointer to a version already listed below, not an
      // image, so nothing under it becomes a download row
      if (!version || version === 'latest') continue;
      if (!byVersion.has(version)) byVersion.set(version, []);
      byVersion.get(version).push(object);
    }
    return html(renderIndex(byVersion));
  },

  headers: (key) => {
    const headers = {
      // A versioned image never changes; the alias is repointed in place.
      'cache-control':
        versionOf(key) === 'latest' ? 'no-cache' : 'public, max-age=31536000, immutable',
    };
    if (key.endsWith('.iso')) {
      // browsers otherwise try to render several gigabytes of ISO
      headers['content-disposition'] = `attachment; filename="${key.split('/').pop()}"`;
    }
    return headers;
  },

  // Where a client can fetch this object without going through the worker.
  // A versioned image is four gigabytes streamed through an invocation
  // that is billed per request; the bucket's own hostname has no worker in
  // front of it, so the hop costs one invocation and the transfer none.
  //
  // Never `latest/`: that key is a pointer repointed at every release, and
  // the handler above reads it and answers its own 302 to the versioned
  // object - which is what keeps a resumed download aimed at an immutable
  // URL. Redirecting the pointer itself would hand a client the moving
  // target instead.
  direct: (key) =>
    versionOf(key) === 'latest' ? null : `${CDN}/${encodeURI(key)}`,
};
