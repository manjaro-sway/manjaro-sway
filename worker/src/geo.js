/**
 * Approximate location and sun times for the caller, from the edge.
 *
 * Cloudflare attaches geo data to every request it terminates, so this
 * needs no lookup, no database and no third party: the request already
 * arrived and the edge already knows roughly where from. That is the same
 * mechanism manjaro-sway's own worker used before we replaced it with
 * get.geojs.io.
 *
 * Nothing here logs or stores anything - no IP, no coordinates, no request
 * metadata, and the site this hangs off binds no KV or D1. That is the
 * whole point: moving the beacon to a host we own would be worse than
 * leaving it, because our users would have less recourse rather than more.
 *
 * Sun times are computed here rather than fetched. Asking an upstream for
 * them would put the caller's coordinates in front of a third party again,
 * which is the thing being removed.
 */

const DEGREES = Math.PI / 180;

/**
 * Sunrise and sunset as UTC epoch milliseconds, or null where the sun does
 * not rise or set that day.
 *
 * NOAA's sunrise equation. Accurate to well under a minute, which is far
 * inside what a theme switch or a weather tooltip can tell apart.
 */
export function sunTimes(date, latitude, longitude) {
  // days since the J2000.0 epoch, at noon
  const julian = Math.floor(date.getTime() / 86400000 + 2440587.5 - 2451545.0 + 0.0008);
  const meanSolarNoon = julian - longitude / 360;
  const meanAnomaly = (357.5291 + 0.98560028 * meanSolarNoon) % 360;
  const centre =
    1.9148 * Math.sin(meanAnomaly * DEGREES) +
    0.02 * Math.sin(2 * meanAnomaly * DEGREES) +
    0.0003 * Math.sin(3 * meanAnomaly * DEGREES);
  const eclipticLongitude = (meanAnomaly + centre + 180 + 102.9372) % 360;
  const solarTransit =
    2451545.0 +
    meanSolarNoon +
    0.0053 * Math.sin(meanAnomaly * DEGREES) -
    0.0069 * Math.sin(2 * eclipticLongitude * DEGREES);
  const declination = Math.asin(
    Math.sin(eclipticLongitude * DEGREES) * Math.sin(23.4397 * DEGREES),
  );

  // -0.833° accounts for refraction and the sun's apparent radius, which
  // is what "sunrise" conventionally means
  const hourAngle =
    (Math.sin(-0.833 * DEGREES) - Math.sin(latitude * DEGREES) * Math.sin(declination)) /
    (Math.cos(latitude * DEGREES) * Math.cos(declination));

  // polar day or polar night: no rise or set to report
  if (hourAngle > 1 || hourAngle < -1) return { sunrise: null, sunset: null };

  const angle = Math.acos(hourAngle) / DEGREES;
  const toEpoch = (julianDay) => (julianDay - 2440587.5) * 86400000;
  return {
    sunrise: toEpoch(solarTransit - angle / 360),
    sunset: toEpoch(solarTransit + angle / 360),
  };
}

/**
 * An ISO timestamp carrying the zone's own offset, e.g.
 * 2026-09-11T06:45+02:00.
 *
 * theme-toggle.sh parses these with `date -d`, so a UTC Z would break the
 * day/night switch for everyone not on UTC.
 */
export function isoWithOffset(epochMillis, timeZone) {
  const date = new Date(epochMillis);
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone,
      hour12: false,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    })
      .formatToParts(date)
      .map((part) => [part.type, part.value]),
  );
  // Intl gives the wall clock in the zone; the offset is the difference
  // between that and UTC, which is the only way to get it without a table
  const asUtc = Date.UTC(
    Number(parts.year),
    Number(parts.month) - 1,
    Number(parts.day),
    Number(parts.hour === '24' ? '00' : parts.hour),
    Number(parts.minute),
    Number(parts.second),
  );
  const offsetMinutes = Math.round((asUtc - date.getTime()) / 60000);
  const sign = offsetMinutes < 0 ? '-' : '+';
  const absolute = Math.abs(offsetMinutes);
  const pad = (n) => String(n).padStart(2, '0');
  const hour = parts.hour === '24' ? '00' : parts.hour;
  return (
    `${parts.year}-${parts.month}-${parts.day}T${hour}:${parts.minute}` +
    `${sign}${pad(Math.floor(absolute / 60))}:${pad(absolute % 60)}`
  );
}

/** The calendar date in a zone, shifted by whole days. */
function dateIn(timeZone, dayOffset = 0) {
  const now = new Date(Date.now() + dayOffset * 86400000);
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    })
      .formatToParts(now)
      .map((part) => [part.type, part.value]),
  );
  return new Date(`${parts.year}-${parts.month}-${parts.day}T12:00:00Z`);
}

/**
 * Seconds until local midnight, so the response is not cached past the day
 * its sun times describe.
 */
function secondsUntilMidnight(timeZone) {
  const now = new Date();
  const midnight = new Date(dateIn(timeZone, 1));
  midnight.setUTCHours(12, 0, 0, 0);
  const seconds = Math.round((midnight.getTime() - now.getTime()) / 1000);
  // never negative, never a whole day: the sun times are the thing expiring
  return Math.max(60, Math.min(seconds, 86400));
}

export async function geo(request) {
  const cf = request.cf;

  // request.cf is only populated on Cloudflare's edge; under `wrangler dev`
  // or on a workers.dev URL it can be missing. Say so rather than serve a
  // half-populated object the clients would cache for six hours.
  if (!cf || cf.latitude === undefined || cf.longitude === undefined) {
    return new Response('no geo data on this request\n', {
      status: 503,
      headers: { 'content-type': 'text/plain', 'cache-control': 'no-store' },
    });
  }

  const latitude = Number(cf.latitude);
  const longitude = Number(cf.longitude);
  const timeZone = cf.timezone || 'UTC';

  const today = sunTimes(dateIn(timeZone), latitude, longitude);
  const tomorrow = sunTimes(dateIn(timeZone, 1), latitude, longitude);
  const stamp = (value) => (value === null ? null : isoWithOffset(value, timeZone));

  const body = {
    // numbers, not strings: geoip.sh's consumers do arithmetic on these
    latitude,
    longitude,
    city: cf.city ?? null,
    country: cf.country ?? null,
    timezone: timeZone,
    sunrise: stamp(today.sunrise),
    sunset: stamp(today.sunset),
    sunrise_tomorrow: stamp(tomorrow.sunrise),
    sunset_tomorrow: stamp(tomorrow.sunset),
  };

  return new Response(`${JSON.stringify(body)}\n`, {
    headers: {
      'content-type': 'application/json',
      // private: this is about the caller, so no shared cache should keep it
      'cache-control': `private, max-age=${secondsUntilMidnight(timeZone)}`,
    },
  });
}
