/**
 * /packages - the pacman repository.
 */

import { escapeHtml, html, humanSize, notFound, page } from './serve.js';

// the section this page is, since the shell already names the site
const TITLE = 'packages';

// The tree the publish workflow writes. Anything else is a typo, and
// answering 404 for it is cheaper than a bucket round trip.
const ARCHES = ['x86_64'];

// The one branch published. `stable` and `testing` are redirected to it in
// index.js before a request reaches this site, so they never appear here.
const BRANCH = 'unstable';

/**
 * The stored key a request path refers to, or null if it names no tree.
 *
 * Clients configure `Server = https://.../packages/<branch>/$arch`, so a
 * real request carries a branch and then an architecture. The branch is
 * stripped here: it selects nothing, because there is one tree.
 */
export function resolveKey(path) {
  if (path === '') return '';
  const [branch, ...rest] = path.split('/');
  if (branch !== BRANCH) return null;
  const within = rest.join('/');
  if (within === '') return '';
  const [arch] = within.split('/');
  return ARCHES.includes(arch) ? within : null;
}

export function renderListing(prefix, dirs, files) {
  const parent = prefix.replace(/[^/]+\/$/, '');
  const base = '/packages/unstable/';
  const rows = [
    prefix
      ? `<tr><td><a href="${base}${escapeHtml(parent)}">../</a></td><td></td><td></td></tr>`
      : '',
    ...dirs.map(
      (d) =>
        `<tr><td><a href="${base}${escapeHtml(d)}">${escapeHtml(
          d.slice(prefix.length),
        )}</a></td><td></td><td></td></tr>`,
    ),
    ...files.map(
      (f) =>
        `<tr><td><a href="${base}${escapeHtml(f.key)}">${escapeHtml(
          f.key.slice(prefix.length),
        )}</a></td><td>${humanSize(f.size)}</td><td>${escapeHtml(
          new Date(f.uploaded).toISOString().slice(0, 16).replace('T', ' '),
        )}</td></tr>`,
    ),
  ].join('\n');

  return page(
    prefix ? `${TITLE}/${prefix}` : TITLE,
    `<div class="listing"><table>\n${rows}\n</table></div>`,
  );
}

/** Serve the repository signing key. */
async function signingKey(request, bucket) {
  const key = await bucket.get('manjaro-sway.gpg');
  if (!key) return notFound();
  return new Response(key.body, {
    headers: {
      'content-type': 'application/pgp-keys',
      'cache-control': 'public, max-age=3600',
    },
  });
}

export const site = {
  bucket: 'PACKAGES',
  base: '/packages/unstable/',
  isListing: (key) => key === '' || key.endsWith('/'),

  resolveKey,

  routes: {
    // the signing key, so a new machine can trust the repository before it
    // has anything from it installed. Reachable under every branch alias,
    // because the key is what a user fetches first and a 404 there reads
    // as the repository being down.
    [`${BRANCH}/manjaro-sway.gpg`]: signingKey,
    [`${BRANCH}/x86_64/manjaro-sway.gpg`]: signingKey,
    'manjaro-sway.gpg': signingKey,
  },

  listing: async (bucket, key) => {
    const listed = await bucket.list({ prefix: key, delimiter: '/' });
    const files = listed.objects.filter((o) => o.key !== key);
    if (!files.length && !listed.delimitedPrefixes.length) return notFound();
    return html(renderListing(key, listed.delimitedPrefixes, files));
  },

  headers: (key) => ({
    // a package is immutable once published - its version is in its name -
    // but the database is rewritten in place on every publish
    'cache-control': /\.pkg\.tar\.zst$/.test(key)
      ? 'public, max-age=31536000, immutable'
      : 'no-cache',
  }),
};
