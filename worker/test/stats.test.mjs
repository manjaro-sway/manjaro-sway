/**
 * Counting is the part that is easy to get quietly wrong: a resumed
 * download issues dozens of range requests, and counting those would
 * report one download as many. The rest of what is pinned here is the
 * behaviour a public page needs - that a missing read token is a sentence
 * rather than a 500, and that an archived month is answered from kv.
 */
import assert from 'node:assert/strict';
import { test } from 'node:test';

import worker from '../src/index.js';
import { site as isoSite } from '../src/iso.js';
import { site as packagesSite } from '../src/packages.js';
import { archiveMonth, closedMonth, counts, monthRange, record, sqlSafe } from '../src/stats.js';
import { bucketOf, get } from './helpers.mjs';

const analytics = () => {
  const written = [];
  return { written, writeDataPoint: (point) => written.push(point) };
};

const kvOf = (entries = {}) => {
  const store = new Map(Object.entries(entries));
  return {
    store,
    list: async ({ prefix = '' } = {}) => ({
      keys: [...store.keys()].filter((k) => k.startsWith(prefix)).map((name) => ({ name })),
    }),
    get: async (key) => store.get(key) ?? null,
    put: async (key, value) => store.set(key, value),
  };
};

test('a resumed download does not count as many downloads', () => {
  // the whole reason 206 is excluded: one image, dozens of range requests
  assert.equal(counts('202609111200/manjaro-sway.iso', 206, 'GET'), false);
  assert.equal(counts('202609111200/manjaro-sway.iso', 200, 'GET'), true);
});

test('a revalidation transfers nothing and does not count', () => {
  assert.equal(counts('202609111200/manjaro-sway.iso', 304, 'GET'), false);
});

test('the checksum file is not a download', () => {
  assert.equal(counts('2026.09.11/SHA256SUMS', 200, 'GET'), false);
});

test('a HEAD is not a download', () => {
  assert.equal(counts('202609111200/manjaro-sway.iso', 200, 'HEAD'), false);
});

test('an image taken from latest/ is not counted', () => {
  // latest/ is an alias, not a version: every download through it redirects
  // to the versioned path and is counted there
  const env = { ANALYTICS_ENGINE: analytics() };
  record(env, 'latest/manjaro-sway.iso', 200, 'GET');
  record(env, '202609111200/manjaro-sway-202609111200.iso', 200, 'GET');
  assert.deepEqual(
    env.ANALYTICS_ENGINE.written.map((p) => p.blobs[2]),
    ['version'],
  );
});

test('serving an iso counts it, serving a package does not', async () => {
  const isoEnv = {
    ISO: bucketOf(['202609111200/manjaro-sway.iso']),
    ANALYTICS_ENGINE: analytics(),
  };
  await worker.fetch(get('iso/202609111200/manjaro-sway.iso'), isoEnv, {});
  assert.equal(isoEnv.ANALYTICS_ENGINE.written.length, 1);

  // every `pacman -Sy` is a database fetch; that volume would dwarf the signal
  const pkgEnv = {
    PACKAGES: bucketOf(['x86_64/manjaro-sway.db.tar.gz']),
    ANALYTICS_ENGINE: analytics(),
  };
  await worker.fetch(get('packages/unstable/x86_64/manjaro-sway.db.tar.gz'), pkgEnv, {});
  assert.equal(pkgEnv.ANALYTICS_ENGINE.written.length, 0);
  assert.equal(packagesSite.record, undefined);
  assert.equal(typeof isoSite.record, 'function');
});

test('counting never breaks the download it is counting', async () => {
  // the versioned key: latest/ is a pointer that redirects, and a 302
  // transfers nothing to count
  const key = '202609101200/manjaro-sway-202609101200.iso';
  const env = {
    ISO: bucketOf([key]),
    ANALYTICS_ENGINE: {
      writeDataPoint: () => {
        throw new Error('analytics is down');
      },
    },
  };
  const response = await worker.fetch(get(`iso/${key}`), env, {});
  assert.equal(response.status, 200);
});

test('an unset token renders the page rather than a 500', async () => {
  const env = { ISO: bucketOf([]), STATS: kvOf() };
  const response = await worker.fetch(get('iso/stats'), env, {});
  assert.equal(response.status, 200);
  assert.match(await response.text(), /not configured/i);
});

test('an archived month is published even with no token', async () => {
  const env = {
    ISO: bucketOf([]),
    STATS: kvOf({ 'month:2026-08': JSON.stringify({ '2026.08.01': 12 }) }),
  };
  const response = await worker.fetch(get('iso/stats.json'), env, {});
  const body = await response.json();
  assert.equal(body.configured, false);
  assert.deepEqual(body.archive, [{ month: '2026-08', totals: { '2026.08.01': 12 } }]);
});

test('an archived month is answered from kv without querying analytics', async () => {
  const env = {
    ISO: bucketOf([]),
    STATS: kvOf({ 'month:2026-07': JSON.stringify({ '2026.07.02': 5 }) }),
    ANALYTICS_TOKEN: 'token',
    ACCOUNT_ID: 'account',
  };
  let queried = 0;
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    queried += 1;
    return new Response(JSON.stringify({ data: [] }), { status: 200 });
  };
  try {
    const response = await worker.fetch(get('iso/stats.json'), env, {});
    const body = await response.json();
    assert.deepEqual(body.archive[0].totals, { '2026.07.02': 5 });
  } finally {
    globalThis.fetch = realFetch;
  }
  // the live half queries; the archive half must not
  assert.equal(queried, 1);
});

test('a failing query leaves the page standing', async () => {
  const env = {
    ISO: bucketOf([]), STATS: kvOf(), ANALYTICS_TOKEN: 'token', ACCOUNT_ID: 'account',
  };
  const realFetch = globalThis.fetch;
  globalThis.fetch = async () => new Response('nope', { status: 500 });
  try {
    const response = await worker.fetch(get('iso/stats'), env, {});
    assert.equal(response.status, 200);
  } finally {
    globalThis.fetch = realFetch;
  }
});

test('the stats page is reachable from the index', async () => {
  // an unlinked page can only be found by knowing the URL, which is how
  // this was missed upstream the first time
  const env = { ISO: bucketOf(['202609111200/manjaro-sway.iso']) };
  const response = await worker.fetch(get('iso/'), env, {});
  assert.match(await response.text(), /href="\/iso\/stats"/);
});

test('a quote in the query string cannot escape the SQL literal', () => {
  assert.equal(sqlSafe("2026.09.11' OR '1'='1"), "2026.09.11'' OR ''1''=''1");
  assert.equal(sqlSafe('x'.repeat(200)).length, 96);
});

test('the archived month is the one before the trigger, not the one it fires in', () => {
  // a cron on the 2nd archives the month that just closed; deriving it from
  // the trigger time means a re-run archives the same month rather than
  // drifting onto the next
  assert.equal(closedMonth(Date.UTC(2026, 8, 2, 3, 17)), '2026-08');
  assert.equal(closedMonth(Date.UTC(2026, 0, 2, 3, 17)), '2025-12');
});

test('the month range is half-open, so month lengths never matter', () => {
  assert.deepEqual(monthRange('2026-02'), {
    start: '2026-02-01 00:00:00',
    end: '2026-03-01 00:00:00',
  });
  assert.deepEqual(monthRange('2026-12'), {
    start: '2026-12-01 00:00:00',
    end: '2027-01-01 00:00:00',
  });
});

test('archiving writes one key holding the month total', async () => {
  const env = { STATS: kvOf(), ANALYTICS_TOKEN: 'token', ACCOUNT_ID: 'account' };
  const realFetch = globalThis.fetch;
  let sql = '';
  globalThis.fetch = async (url, init) => {
    sql = init.body;
    return new Response(
      JSON.stringify({ data: [{ version: '2026.08.01', downloads: '9' }] }),
      { status: 200 },
    );
  };
  try {
    await archiveMonth(env, '2026-08');
  } finally {
    globalThis.fetch = realFetch;
  }
  assert.deepEqual(JSON.parse(env.STATS.store.get('month:2026-08')), { '2026.08.01': 9 });
  // a hyphen is not a bare SQL identifier: unquoted this is a parser error
  assert.match(sql, /FROM "manjaro-sway-iso-downloads"/);
  // toDateTime, not toDate, which the SQL API rejects for a STRING
  assert.match(sql, /toDateTime\('2026-08-01 00:00:00'\)/);
});
