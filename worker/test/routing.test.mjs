/**
 * One hostname, three things behind it. The thing worth pinning is that
 * they stay apart: a path under one mount must never read the other's
 * bucket, and anything outside a mount must reach the landing page rather
 * than a bucket listing.
 */
import assert from 'node:assert/strict';
import { test } from 'node:test';

import worker, { mountFor } from '../src/index.js';
import { site as isoSite } from '../src/iso.js';
import { site as packagesSite } from '../src/packages.js';
import { bucketOf, get } from './helpers.mjs';

const PACKAGE_KEYS = ['x86_64/manjaro-sway.db.tar.gz', 'manjaro-sway.gpg'];
const ISO_KEYS = ['202609101200/manjaro-sway-202609101200.iso', 'latest/manjaro-sway.iso'];

const docs = () => new Response('<h1>Manjaro Sway</h1>');
const env = (fetchDocs = docs) => ({
  PACKAGES: bucketOf(PACKAGE_KEYS),
  ISO: bucketOf(ISO_KEYS),
  DOCS: { fetch: fetchDocs },
});

test('each mount reaches its own site', () => {
  assert.equal(mountFor('/packages/unstable/x86_64/x').site, packagesSite);
  assert.equal(mountFor('/iso/latest').site, isoSite);
  assert.equal(mountFor('/'), null);
  assert.equal(mountFor('/img/logo.png'), null);
});

test('the bare domain redirects to the edition, keeping the path', async () => {
  // manjaro.download reads like the distribution's own domain; this
  // project does not serve under it. The path survives so an existing
  // link to a deep page still lands on that page.
  const res = await worker.fetch(
    new Request('https://manjaro.download/iso/latest'),
    env(),
  );
  assert.equal(res.status, 301);
  assert.equal(res.headers.get('location'), 'https://manjaro-sway.download/iso/latest');
});

test('the redirect is exact-match, so sway.manjaro.download still serves', async () => {
  // A suffix test would have caught the subdomain the whole site runs on
  // and bounced every request away from it
  const res = await worker.fetch(
    new Request('https://sway.manjaro.download/packages/unstable/x86_64/manjaro-sway.db.tar.gz'),
    env(),
  );
  assert.notEqual(res.status, 301);
});

test('/geo redirects to the deployment that answers it now', async () => {
  // Installs carry the old URL in their shipped copy of geoip.sh until the
  // settings package updates, so this is what keeps those desktops working.
  // Both callers follow redirects - geoip.sh curls with -L, requests does
  // by default - so the hop is invisible to them.
  const res = await worker.fetch(get('geo'), env());
  // 302 exactly: a 301 is cached by the client forever, so the hop could
  // never be repointed if that deployment moves
  assert.equal(res.status, 302);
  assert.equal(res.headers.get('location'), 'https://ashlaros.download/geo');
});

test('the mount prefix is stripped before the site sees the path', () => {
  // the buckets hold unprefixed keys, so a site that saw `/packages/...`
  // would look up a key that cannot exist
  assert.equal(mountFor('/packages/unstable/x86_64/x').path, '/unstable/x86_64/x');
  assert.equal(mountFor('/iso/202609101200/x.iso').path, '/202609101200/x.iso');
});

test('a mount without a trailing slash is its index, not a miss', () => {
  // a link to /iso would otherwise fall through to the landing page
  assert.equal(mountFor('/iso').path, '/');
  assert.equal(mountFor('/packages').path, '/');
});

test('the iso mount cannot read the packages bucket', async () => {
  // sharing a script must not share buckets: each site names its own
  // binding, so a key that exists in the other one still misses
  const res = await worker.fetch(get('iso/x86_64/manjaro-sway.db.tar.gz'), env());
  assert.equal(res.status, 404);
});

test('the packages mount cannot read the iso bucket', async () => {
  const res = await worker.fetch(
    get('packages/unstable/202609101200/manjaro-sway-202609101200.iso'),
    env(),
  );
  assert.equal(res.status, 404);
});

test("the packages signing-key route does not exist under the iso mount", async () => {
  const onPackages = await worker.fetch(get('packages/unstable/manjaro-sway.gpg'), env());
  assert.equal(onPackages.status, 200);

  const onIso = await worker.fetch(get('iso/manjaro-sway.gpg'), env());
  assert.equal(onIso.status, 404);
});

test('each mount root renders its own index', async () => {
  const packages = await worker.fetch(get('packages/unstable/'), env());
  assert.match(await packages.text(), /x86_64/);

  const iso = await worker.fetch(get('iso/'), env());
  const body = await iso.text();
  assert.match(body, /latest\/manjaro-sway\.iso/);
  assert.doesNotMatch(body, /x86_64\/manjaro-sway\.db/);
});

test('anything outside a mount is the landing page, not a bucket', async () => {
  // if a stray path fell through to a site handler it would expose bucket
  // keys under the marketing URL
  let asked;
  const withDocs = env((request) => ((asked = request.url), docs()));

  const res = await worker.fetch(get(''), withDocs);
  assert.match(await res.text(), /Manjaro Sway/);
  assert.equal(asked, 'https://sway.manjaro.download/');

  // a key that exists in a bucket is still the landing page here
  const key = await worker.fetch(get('x86_64/manjaro-sway.db.tar.gz'), withDocs);
  assert.match(await key.text(), /Manjaro Sway/);
});

test('the signing key is at the root as well, ahead of the docs binding', async () => {
  // the documentation gives this URL, and the assets binding would answer
  // 404 for it if the route did not run first
  const res = await worker.fetch(get('gpg-public-key.asc'), env());
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('content-type'), 'application/pgp-keys');
});

test('the favicon is served at the root, where every page links it', async () => {
  // the listing pages link /favicon.svg absolutely, which is outside any
  // mount - so the docs binding would answer 404 without this route
  for (const path of ['favicon.svg', 'favicon.ico']) {
    const res = await worker.fetch(get(path), env());
    assert.equal(res.status, 200, path);
    assert.equal(res.headers.get('content-type'), 'image/svg+xml');
  }
});
