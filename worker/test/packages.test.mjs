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

test('packages are immutable, the database is not', async () => {
  // a cached database is a client that cannot see a package published
  // since; a re-fetched package is bandwidth spent on bytes that cannot
  // have changed
  const pkg = await worker.fetch(
    req('packages/unstable/x86_64/swayr-0.27.3-1-x86_64.pkg.tar.zst'),
    env(),
  );
  assert.match(pkg.headers.get('cache-control'), /immutable/);

  const db = await worker.fetch(req('packages/unstable/x86_64/manjaro-sway.db.tar.gz'), env());
  assert.equal(db.headers.get('cache-control'), 'no-cache');
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

test('a listing links to paths that resolve', async () => {
  const res = await worker.fetch(req('packages/unstable/x86_64/'), env());
  const body = await res.text();
  // the link has to carry the mount and a branch, or following it 404s
  assert.match(body, /href="\/packages\/unstable\/x86_64\/manjaro-sway\.db\.tar\.gz"/);
});
