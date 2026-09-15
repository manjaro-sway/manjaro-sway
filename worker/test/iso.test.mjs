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
import { renderIndex, versionOf } from '../src/iso.js';
import { bucketOf, get } from './helpers.mjs';

const KEYS = [
  '202609101200/manjaro-sway-unstable-202609101200-linux612.iso',
  '202609101200/SHA256SUMS',
  '202608011200/manjaro-sway-unstable-202608011200-linux612.iso',
  'latest/manjaro-sway.iso',
];

const env = () => ({ PACKAGES: bucketOf([]), ISO: bucketOf(KEYS) });
const req = (path) => get(`iso/${path}`);

test('an iso is offered as a download, not rendered', async () => {
  const res = await worker.fetch(
    req('202609101200/manjaro-sway-unstable-202609101200-linux612.iso'),
    env(),
  );
  assert.equal(res.status, 200);
  assert.match(res.headers.get('content-disposition'), /attachment/);
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

test('a versioned image is immutable', async () => {
  const res = await worker.fetch(
    req('202609101200/manjaro-sway-unstable-202609101200-linux612.iso'),
    env(),
  );
  assert.match(res.headers.get('cache-control'), /immutable/);
});

test('a range request is answered as a range, so a download resumes', async () => {
  const request = new Request(
    'https://sway.manjaro.download/iso/202609101200/manjaro-sway-unstable-202609101200-linux612.iso',
    { headers: { range: 'bytes=1000-2000' } },
  );
  const res = await worker.fetch(request, env());
  assert.equal(res.status, 206);
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
