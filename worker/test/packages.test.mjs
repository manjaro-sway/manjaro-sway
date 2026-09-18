/**
 * What the packages site serves, and what it refuses.
 *
 * The routes here are the ones a pacman client depends on: an arch-keyed
 * database under a branch, the packages it names, and the signing key a
 * machine needs before it can install anything.
 */
import assert from 'node:assert/strict';
import { test } from 'node:test';

import worker from '../src/index.js';
import { resolveKey } from '../src/packages.js';
import { bucketOf, get } from './helpers.mjs';

const KEYS = [
  'x86_64/manjaro-sway.db.tar.gz',
  'x86_64/manjaro-sway.db',
  'x86_64/manjaro-sway-settings-17.2.5-12-any.pkg.tar.zst',
  'x86_64/swayr-0.27.3-1-x86_64.pkg.tar.zst',
  // the signature beside a package: it is rewritten whenever that package
  // is republished, so it must never be redirected to a cacheable host
  'x86_64/swayr-0.27.3-1-x86_64.pkg.tar.zst.sig',
  'manjaro-sway.gpg',
];

const env = () => ({ PACKAGES: bucketOf(KEYS), ISO: bucketOf([]) });
const req = (path) => get(path);

test('the published tree is served under its branch', async () => {
  const res = await worker.fetch(req('packages/unstable/x86_64/manjaro-sway.db.tar.gz'), env());
  assert.equal(res.status, 200);
});

test('an unpublished branch redirects to the one that is', async () => {
  // A client configured for stable was being served unstable packages with
  // nothing anywhere to say so. Redirecting keeps that client working and
  // makes the substitution visible in its output and in the logs.
  for (const branch of ['stable', 'testing']) {
    const res = await worker.fetch(
      req(`packages/${branch}/x86_64/manjaro-sway.db.tar.gz`),
      env(),
    );
    assert.equal(res.status, 301, branch);
    assert.equal(
      res.headers.get('location'),
      'https://sway.manjaro.download/packages/unstable/x86_64/manjaro-sway.db.tar.gz',
      branch,
    );
  }
});

test('the redirect carries the whole path, not just the database', async () => {
  // pacman fetches the package and its signature from the same Server line
  const res = await worker.fetch(
    req('packages/stable/x86_64/swayr-0.27.3-1-x86_64.pkg.tar.zst.sig'),
    env(),
  );
  assert.equal(res.status, 301);
  assert.match(res.headers.get('location'), /\/packages\/unstable\/x86_64\/swayr-.*\.sig$/);
});

test('a path naming no known tree is refused without touching the bucket', async () => {
  // a typo'd $arch must not become a bucket listing: R2 would answer with
  // an empty page, which reads to a client as an empty repository rather
  // than a misconfiguration
  let listed = false;
  const bucket = bucketOf(KEYS);
  const spy = {
    PACKAGES: {
      ...bucket,
      list: async (...args) => {
        listed = true;
        return bucket.list(...args);
      },
    },
    ISO: bucketOf([]),
  };
  const res = await worker.fetch(
    req('packages/unstable/x86_64_v3/manjaro-sway.db.tar.gz'),
    spy,
  );
  assert.equal(res.status, 404);
  assert.equal(listed, false);
});

test('an unknown branch is refused', async () => {
  const res = await worker.fetch(req('packages/nightly/x86_64/manjaro-sway.db.tar.gz'), env());
  assert.equal(res.status, 404);
});

test('the signing key is fetchable, because trusting it precedes installing anything', async () => {
  // under the branch, as prepare-container.sh fetches it
  const branched = await worker.fetch(req('packages/unstable/manjaro-sway.gpg'), env());
  assert.equal(branched.status, 200);
  assert.equal(branched.headers.get('content-type'), 'application/pgp-keys');

  // and at the root, which is the URL the documentation gives
  const root = await worker.fetch(req('gpg-public-key.asc'), env());
  assert.equal(root.status, 200);
  assert.equal(root.headers.get('content-type'), 'application/pgp-keys');
});

test('a package is redirected to the bucket, the database is served here', async () => {
  // The split that matters: a package cannot change under a client, so it
  // is sent to the CDN hostname and costs this worker one invocation
  // instead of one per request. The database is rewritten on every
  // publish, so it stays here - a client pointed at a cacheable copy of it
  // is a client installing against a package list it cannot verify.
  const pkg = await worker.fetch(
    req('packages/unstable/x86_64/swayr-0.27.3-1-x86_64.pkg.tar.zst'),
    env(),
  );
  assert.equal(pkg.status, 302);
  assert.equal(
    pkg.headers.get('location'),
    'https://cdn.manjaro-sway.download/x86_64/swayr-0.27.3-1-x86_64.pkg.tar.zst',
  );

  const db = await worker.fetch(req('packages/unstable/x86_64/manjaro-sway.db.tar.gz'), env());
  assert.equal(db.status, 200);
  assert.equal(db.headers.get('cache-control'), 'no-cache');
});

test('a signature is served here, never redirected', async () => {
  // A .sig is rewritten when a package is republished at an unchanged
  // version, so it is exactly the file that must not come from a host that
  // may hold an older copy: a stale signature against a fresh package is
  // "signature is invalid" on the client.
  const sig = await worker.fetch(
    req('packages/unstable/x86_64/swayr-0.27.3-1-x86_64.pkg.tar.zst.sig'),
    env(),
  );
  assert.equal(sig.status, 200);
  assert.equal(sig.headers.get('cache-control'), 'no-cache');
});

test('a range request is answered as a range', async () => {
  const request = new Request(
    'https://sway.manjaro.download/packages/unstable/x86_64/manjaro-sway.db.tar.gz',
    { headers: { range: 'bytes=0-3' } },
  );
  const res = await worker.fetch(request, env());
  assert.equal(res.status, 206);
});

test('an absent object is 404, not an empty 200', async () => {
  const res = await worker.fetch(
    req('packages/unstable/x86_64/nothing-here.pkg.tar.zst'),
    env(),
  );
  assert.equal(res.status, 404);
});

test('a write method is refused', async () => {
  const request = new Request(
    'https://sway.manjaro.download/packages/unstable/x86_64/manjaro-sway.db.tar.gz',
    { method: 'DELETE' },
  );
  const res = await worker.fetch(request, env());
  assert.equal(res.status, 405);
});

const legacy = (path) => new Request(`https://packages.manjaro-sway.download/${path}`);

test('the legacy host serves the repository, whatever branch it names', async () => {
  // Every install made from an older ISO has
  // Server = https://packages.manjaro-sway.download/<branch>/$arch in its
  // pacman.conf, and those machines cannot be edited from here.
  for (const branch of ['unstable', 'testing', 'stable']) {
    const res = await worker.fetch(legacy(`${branch}/x86_64/manjaro-sway.db.tar.gz`), env());
    assert.equal(res.status, 200, branch);
  }
});

test('the legacy host serves the signing key its pacman.conf trusts', async () => {
  const res = await worker.fetch(legacy('manjaro-sway.gpg'), env());
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('content-type'), 'application/pgp-keys');
});

test('the legacy host cannot reach the iso bucket', async () => {
  // it is the repository host and nothing else; a path that looks like an
  // image key must miss rather than cross into the other bucket
  const res = await worker.fetch(legacy('202609160023/manjaro-sway.iso'), env());
  assert.equal(res.status, 404);
});

test('resolveKey strips the branch and admits only the published tree', () => {
  assert.equal(resolveKey(''), '');
  assert.equal(resolveKey('unstable'), '');
  assert.equal(resolveKey('unstable/x86_64/'), 'x86_64/');
  assert.equal(resolveKey('unstable/x86_64/manjaro-sway.db'), 'x86_64/manjaro-sway.db');
  // the unpublished branches never reach here: index.js redirects them
  assert.equal(resolveKey('stable/x86_64/manjaro-sway.db'), null);
  assert.equal(resolveKey('unstable/aarch64/manjaro-sway.db'), null);
  assert.equal(resolveKey('unstable/../secrets'), null);
  assert.equal(resolveKey('../secrets'), null);
});

test('a listing links to paths that resolve, on either hostname', async () => {
  // The same listing is served under two hostnames whose paths differ, so
  // what matters is that a link resolves from where it is shown - not what
  // string it contains. This test used to pin the absolute form, which is
  // precisely why every link on the legacy host 404'd.
  for (const [url, dir] of [
    ['https://sway.manjaro.download/packages/unstable/x86_64/', '/packages/unstable/x86_64/'],
    ['https://packages.manjaro-sway.download/unstable/x86_64/', '/unstable/x86_64/'],
  ]) {
    const res = await worker.fetch(new Request(url), env());
    const body = await res.text();
    const href = body.match(/href="([^"]*manjaro-sway\.db\.tar\.gz)"/)?.[1];
    assert.ok(href, `no db link in the listing at ${url}`);
    // resolved the way a browser would, against the directory being shown
    assert.equal(new URL(href, url).pathname, `${dir}manjaro-sway.db.tar.gz`);
  }
});
