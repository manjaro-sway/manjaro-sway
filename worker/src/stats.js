/**
 * Download counting for the ISO downloads.
 *
 * Two stores, because neither alone works:
 *
 *   analytics engine  version, name, alias   three months
 *   kv                month, version         indefinitely
 *
 * writeDataPoint is non-blocking, so counting costs a download nothing -
 * but analytics engine only retains three months. A cron on the 2nd of
 * each month rolls the month that just closed into one kv key, which is
 * kept for good. The 2nd rather than the 1st: ingestion is not instant,
 * and a closed month's final events have to be queryable before the month
 * is archived.
 *
 * Nothing writes kv from a request. Kv allows one write per second per key
 * and propagates globally for up to 60s, so a counter incremented per
 * download would lose counts to last-write-wins.
 *
 * Writing needs no credentials; reading does. Analytics engine has no
 * query binding, so reads go over the SQL API with a bearer token. That
 * asymmetry is deliberate: downloads are counted whether or not the token
 * is set, and it can be added later without losing anything.
 */

const DATASET = 'manjaro-sway-iso-downloads';
const SQL_ENDPOINT = (accountId) =>
  `https://api.cloudflare.com/client/v4/accounts/${accountId}/analytics_engine/sql`;

/**
 * A value safe to paste into a SQL string literal.
 *
 * Filter values arrive in the query string, so they are attacker
 * controlled. Doubling the quote is the escape the SQL API accepts; the
 * length cap keeps a pathological value from becoming the whole query.
 */
export function sqlSafe(value) {
  return String(value).slice(0, 96).replace(/'/g, "''");
}

/**
 * Whether a response to this request counts as one download.
 *
 * Only a whole-image GET that actually transferred. A resumed download
 * issues many range requests, so counting 206 would report one download as
 * dozens; a 304 transfers nothing; SHA256SUMS is not a download.
 */
export function counts(key, status, method) {
  return method === 'GET' && status === 200 && key.endsWith('.iso');
}

/**
 * Record one download. Never throws into the response path: a counting
 * failure must not cost the user their image.
 */
export function record(env, key, status, method) {
  if (!counts(key, status, method)) return;
  if (!env.ANALYTICS_ENGINE) return;

  const cut = key.indexOf('/');
  const prefix = cut === -1 ? '' : key.slice(0, cut);
  const name = cut === -1 ? key : key.slice(cut + 1);
  // latest/ is an alias, not a version: every download through it redirects
  // to the versioned path and is counted there. Recording it separately
  // would double-count and produce a meaningless "latest (unpinned)" row.
  if (prefix === 'latest') return;
  const alias = 'version';

  try {
    env.ANALYTICS_ENGINE.writeDataPoint({
      blobs: [prefix, name, alias],
      doubles: [1],
      indexes: [prefix],
    });
  } catch {
    // counting is best effort
  }
}

async function query(env, sql) {
  const response = await fetch(SQL_ENDPOINT(env.ACCOUNT_ID), {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.ANALYTICS_TOKEN}`,
      'content-type': 'text/plain',
    },
    body: sql,
  });
  if (!response.ok) {
    throw new Error(`analytics query failed: ${response.status}`);
  }
  return (await response.json()).data ?? [];
}

/**
 * Downloads per version over the retained window.
 *
 * The dataset name is quoted every time: a hyphen is not a bare SQL
 * identifier, and unquoted this is a parser error rather than a bad
 * result.
 */
export async function liveTotals(env) {
  const rows = await query(
    env,
    `SELECT blob1 AS version, SUM(_sample_interval) AS downloads
     FROM "${DATASET}"
     GROUP BY version
     ORDER BY downloads DESC`,
  );
  return rows.map((row) => ({
    version: row.version,
    downloads: Number(row.downloads),
  }));
}

/** Downloads per file within one version, over the retained window. */
export async function liveFiles(env, version) {
  const rows = await query(
    env,
    `SELECT blob2 AS name, SUM(_sample_interval) AS downloads
     FROM "${DATASET}"
     WHERE blob1 = '${sqlSafe(version)}'
     GROUP BY name
     ORDER BY downloads DESC`,
  );
  return rows.map((row) => ({ name: row.name, downloads: Number(row.downloads) }));
}

/** The YYYY-MM a scheduled run should archive: the month before it fires. */
export function closedMonth(scheduledTime) {
  const at = new Date(scheduledTime);
  // deriving it from the trigger time rather than from "now" means a late
  // or re-run invocation archives the same month instead of drifting
  const year = at.getUTCFullYear();
  const month = at.getUTCMonth(); // 0-based, so this is already last month
  const first = new Date(Date.UTC(year, month - 1, 1));
  return `${first.getUTCFullYear()}-${String(first.getUTCMonth() + 1).padStart(2, '0')}`;
}

/** [start, end) as the SQL API's datetime literals, for a YYYY-MM. */
export function monthRange(month) {
  const [year, index] = month.split('-').map(Number);
  const pad = (n) => String(n).padStart(2, '0');
  const start = `${year}-${pad(index)}-01 00:00:00`;
  const nextYear = index === 12 ? year + 1 : year;
  const nextMonth = index === 12 ? 1 : index + 1;
  const end = `${nextYear}-${pad(nextMonth)}-01 00:00:00`;
  return { start, end };
}

/**
 * Fold one closed month into kv, before analytics engine forgets it.
 *
 * toDateTime with a half-open range rather than toDate: the SQL API
 * rejects a STRING there, and a half-open range needs no reasoning about
 * month lengths.
 */
export async function archiveMonth(env, month) {
  const { start, end } = monthRange(month);
  const rows = await query(
    env,
    `SELECT blob1 AS version, SUM(_sample_interval) AS downloads
     FROM "${DATASET}"
     WHERE timestamp >= toDateTime('${sqlSafe(start)}')
       AND timestamp < toDateTime('${sqlSafe(end)}')
     GROUP BY version`,
  );

  const totals = {};
  for (const row of rows) totals[row.version] = Number(row.downloads);
  await env.STATS.put(`month:${month}`, JSON.stringify(totals));
  return totals;
}

/** Every archived month, newest first. */
export async function archivedMonths(env) {
  if (!env.STATS) return [];
  const listed = await env.STATS.list({ prefix: 'month:' });
  const months = [];
  for (const entry of listed.keys.sort((a, b) => b.name.localeCompare(a.name))) {
    const raw = await env.STATS.get(entry.name);
    if (raw) months.push({ month: entry.name.slice('month:'.length), totals: JSON.parse(raw) });
  }
  return months;
}

/**
 * Everything the page and the JSON both render.
 *
 * `configured` is false when no read token is set. The page is public, so
 * it says so rather than answering 500 - a 500 reads as "the numbers are
 * broken" when the truth is "nobody has added the token yet". The archive
 * is kv, so it is published either way.
 */
export async function collect(env, version) {
  const archive = await archivedMonths(env);
  if (!env.ANALYTICS_TOKEN || !env.ACCOUNT_ID) {
    return { configured: false, archive, versions: [], files: null, version };
  }
  try {
    const versions = await liveTotals(env);
    const files = version ? await liveFiles(env, version) : null;
    return { configured: true, archive, versions, files, version };
  } catch {
    // a failing query must not take the page down with it
    return { configured: false, archive, versions: [], files: null, version };
  }
}
