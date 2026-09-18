/**
 * What the ISO site serves.
 *
 * The load-bearing behaviours are: an ISO downloads rather than renders,
 * a resumed download works, `latest/` is never cached as if it were
 * immutable - a stale `latest` hands out last month's image forever - and
 * /iso/latest describes the current release to the landing page.
 */
import assert from 'node:assert/strict';
import { test } from 'node:test';

import worker from '../src/index.js';
import { renderIndex, site as isoSite, versionOf } from '../src/iso.js';
import { bucketOf, get } from './helpers.mjs';

const KEYS = [
  '202609101200/manjaro-sway-unstable-202609101200-linux612.iso',
  '202609101200/SHA256SUMS',
  '202608011200/manjaro-sway-unstable-202608011200-linux612.iso',
  'latest/manjaro-sway.iso',
];

const env = () => ({ PACKAGES: bucketOf([]), ISO: bucketOf(KEYS) });
const req = (path) => get(`iso/${path}`);

test('a versioned image is redirected to the bucket that serves it', async () => {
  // Four gigabytes no longer stream through an invocation that is billed
  // per request. What the worker still owes the client is the right
  // target: the same key on the bucket's own hostname.
  //
  // content-disposition moved with it - upload_iso.py stores it on the
  // object, because the CDN serves the object's own metadata and knows
  // nothing about this handler. That is not assertable from here, which is
  // why it is set at upload rather than added per response.
  const res = await worker.fetch(
    req('202609101200/manjaro-sway-unstable-202609101200-linux612.iso'),
    env(),
  );
  assert.equal(res.status, 302);
  assert.equal(
    res.headers.get('location'),
    'https://iso.manjaro-sway.download/202609101200/manjaro-sway-unstable-202609101200-linux612.iso',
  );
});

test('an alias key holding a whole image is refused, not read', async () => {
  // The bug this defends, seen in the sibling repository: latest/ still
  // held the image it used to be a server-side copy of, and reading two
  // gigabytes as a pointer killed the isolate - Cloudflare error 1101, a
  // 500 on the download link. A body too large to be a version string is
  // never read at all, so a bad object degrades to 404 instead.
  const iso = bucketOf(KEYS);
  const huge = {
    ...(await iso.get('latest/manjaro-sway.iso')),
    size: 1_978_718_208,
    text: async () => {
      throw new Error('a whole image must never be read as a pointer');
    },
  };
  const res = await worker.fetch(req('latest/manjaro-sway.iso'), {
    PACKAGES: bucketOf([]),
    ISO: { ...iso, get: async () => huge },
  });
  assert.equal(res.status, 404);
});

test('latest redirects to the versioned object it points at', async () => {
  // a redirect rather than a stream: `latest/` is repointed every release,
  // and a client resuming across one would splice two different images
  const res = await worker.fetch(req('latest/manjaro-sway.iso'), env());
  assert.equal(res.status, 302);
  assert.equal(
    res.headers.get('location'),
    '/iso/202609101200/manjaro-sway-unstable-202609101200-linux612.iso',
  );
  assert.equal(res.headers.get('cache-control'), 'no-cache');
});

test('the alias is served here and the version is not', async () => {
  // latest/ is a pointer this worker reads and answers with its own 302 to
  // the versioned object, so a resumed download aims at an immutable URL.
  // Redirecting the pointer to the bucket instead would hand the client
  // the moving target.
  assert.equal(isoSite.direct('latest/manjaro-sway.iso'), null);
  assert.match(
    isoSite.direct('202609101200/manjaro-sway-unstable-202609101200-linux612.iso'),
    /^https:\/\/iso\.manjaro-sway\.download\//,
  );
});

test('a resumed download is redirected too, not streamed from here', async () => {
  // A resume is the case worth handing off: excluding it sent a partial
  // four gigabyte transfer back through the worker, which is the whole
  // cost this redirect exists to avoid. The bucket hostname answers
  // ranges natively, so the client gets its 206 from there.
  const request = new Request(
    'https://sway.manjaro.download/iso/202609101200/manjaro-sway-unstable-202609101200-linux612.iso',
    { headers: { range: 'bytes=1000-2000' } },
  );
  const res = await worker.fetch(request, env());
  assert.equal(res.status, 302);
  assert.match(res.headers.get('location'), /^https:\/\/iso\.manjaro-sway\.download\//);
});

test('an absent image is 404', async () => {
  const res = await worker.fetch(req('202701010000/nope.iso'), env());
  assert.equal(res.status, 404);
});

test('the index lists newest first and does not repeat latest as a version', async () => {
  const res = await worker.fetch(get('iso'), env());
  const body = await res.text();
  assert.ok(
    body.indexOf('202609101200') < body.indexOf('202608011200'),
    'newest version should come first',
  );
  // latest/ is an alias of an image already listed under its own version
  assert.doesNotMatch(body, /<h2>latest<\/h2>/);
  assert.match(body, /href="\/iso\/latest\/manjaro-sway\.iso"/);
});

test('/iso/latest describes the current release', async () => {
  // the landing page renders its download button from this, so a release
  // reaches the page without the page being rebuilt
  const res = await worker.fetch(req('latest'), env());
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.version, '202609101200');
  assert.equal(body.name, 'manjaro-sway-unstable-202609101200-linux612.iso');
  assert.equal(
    body.url,
    '/iso/202609101200/manjaro-sway-unstable-202609101200-linux612.iso',
  );
  // the hash itself, so the page can show it rather than link to a file
  assert.equal(body.sha256, 'bytes');
});

test('/iso/latest says so when nothing is published', async () => {
  const empty = { PACKAGES: bucketOf([]), ISO: bucketOf([]) };
  const res = await worker.fetch(req('latest'), empty);
  assert.equal(res.status, 404);
});

test('versionOf reads the prefix, and rejects a bare key', () => {
  assert.equal(versionOf('202609101200/x.iso'), '202609101200');
  assert.equal(versionOf('latest/manjaro-sway.iso'), 'latest');
  assert.equal(versionOf('stray.iso'), null);
});

test('the index links every object under a version', () => {
  const byVersion = new Map([
    [
      '202609131200',
      [
        { key: '202609131200/manjaro-sway-unstable-202609131200-linux612.iso', size: 1 },
        { key: '202609131200/SHA256SUMS', size: 1 },
      ],
    ],
  ]);
  const body = renderIndex(byVersion);
  assert.match(body, /href="\/iso\/202609131200\/manjaro-sway-unstable-202609131200-linux612\.iso"/);
  assert.match(body, /href="\/iso\/202609131200\/SHA256SUMS"/);
});
