/**
 * The geo route replaces a third-party call the desktop used to make, so
 * what is worth pinning is the contract its consumers read: geoip.sh does
 * arithmetic on the coordinates, and theme-toggle.sh parses the timestamps
 * with `date -d`. A UTC `Z` or a string coordinate would break those
 * silently on every machine not on UTC.
 */
import assert from 'node:assert/strict';
import { test } from 'node:test';

import worker from '../src/index.js';
import { isoWithOffset, sunTimes } from '../src/geo.js';

const withCf = (cf) => {
  const request = new Request('https://sway.manjaro.download/geo');
  // request.cf is not settable on a plain Request; the runtime attaches it
  Object.defineProperty(request, 'cf', { value: cf });
  return request;
};

const BERLIN = {
  latitude: '52.5200',
  longitude: '13.4050',
  city: 'Berlin',
  country: 'DE',
  timezone: 'Europe/Berlin',
};

test('coordinates come back as numbers, not strings', async () => {
  const response = await worker.fetch(withCf(BERLIN), {}, {});
  const body = await response.json();
  assert.equal(typeof body.latitude, 'number');
  assert.equal(typeof body.longitude, 'number');
});

test('timestamps carry the zone offset, so date -d can parse them', async () => {
  const response = await worker.fetch(withCf(BERLIN), {}, {});
  const body = await response.json();
  for (const key of ['sunrise', 'sunset', 'sunrise_tomorrow', 'sunset_tomorrow']) {
    assert.match(
      body[key],
      /^\d{4}-\d\d-\d\dT\d\d:\d\d[+-]\d\d:\d\d$/,
      `${key} must be offset-aware ISO, got ${body[key]}`,
    );
  }
});

test('every key the shell consumers read is present', async () => {
  const response = await worker.fetch(withCf(BERLIN), {}, {});
  const body = await response.json();
  // geoip.sh emits exactly these; sunset.sh and theme-toggle.sh read them
  assert.deepEqual(Object.keys(body).sort(), [
    'city', 'country', 'latitude', 'longitude', 'sunrise',
    'sunrise_tomorrow', 'sunset', 'sunset_tomorrow', 'timezone',
  ]);
});

test('a request without edge geo data says so rather than half-answering', async () => {
  // `wrangler dev` and workers.dev carry no request.cf. Serving a partial
  // object would be cached by the clients for six hours.
  const response = await worker.fetch(withCf(undefined), {}, {});
  assert.equal(response.status, 503);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('missing coordinates are not treated as zero', async () => {
  const response = await worker.fetch(
    withCf({ city: 'Somewhere', timezone: 'UTC' }), {}, {},
  );
  assert.equal(response.status, 503);
});

test('the response is not cached past the day its sun times describe', async () => {
  const response = await worker.fetch(withCf(BERLIN), {}, {});
  const cacheControl = response.headers.get('cache-control');
  assert.match(cacheControl, /^private, max-age=\d+$/);
  const maxAge = Number(cacheControl.match(/max-age=(\d+)/)[1]);
  assert.ok(maxAge <= 86400, `max-age ${maxAge} outlives the day`);
});

test('polar day and polar night report no sunrise rather than a wrong one', () => {
  const midwinter = sunTimes(new Date('2026-12-21T12:00:00Z'), 78.22, 15.63);
  assert.equal(midwinter.sunrise, null);
  assert.equal(midwinter.sunset, null);
});

test('sun times match MET Norway to within two minutes', () => {
  // MET's own answer for Berlin on this date, fetched from their sunrise
  // API: 06:33+02:00 and 19:31+02:00
  const { sunrise, sunset } = sunTimes(new Date('2026-09-11T12:00:00Z'), 52.52, 13.41);
  const minutes = (stamp) => {
    const [h, m] = stamp.slice(11, 16).split(':').map(Number);
    return h * 60 + m;
  };
  const rise = minutes(isoWithOffset(sunrise, 'Europe/Berlin'));
  const set = minutes(isoWithOffset(sunset, 'Europe/Berlin'));
  assert.ok(Math.abs(rise - (6 * 60 + 33)) <= 2, `sunrise off by ${rise - 393} min`);
  assert.ok(Math.abs(set - (19 * 60 + 31)) <= 2, `sunset off by ${set - 1171} min`);
});

test('a fractional zone offset is formatted correctly', () => {
  // Kathmandu is +05:45; an hours-only formatter would write +05:00
  const { sunrise } = sunTimes(new Date('2026-09-11T12:00:00Z'), 27.71, 85.32);
  assert.match(isoWithOffset(sunrise, 'Asia/Kathmandu'), /\+05:45$/);
});

test('the docs site still serves everything else', async () => {
  let servedByDocs = false;
  const env = { DOCS: { fetch: async () => { servedByDocs = true; return new Response('page'); } } };
  await worker.fetch(new Request('https://sway.manjaro.download/'), env, {});
  assert.ok(servedByDocs, '/ must still reach the docs binding');
});
