/**
 * One worker for everything manjaro-sway serves: the landing page, the
 * pacman repository, and the ISO downloads.
 *
 * Routing is by path, not by hostname. There is one hostname -
 * sway.manjaro.download - and the two buckets sit under `/packages/` and
 * `/iso/` beneath it. Each site definition (./packages.js, ./iso.js) names
 * its own binding, so neither can read the other's bucket; everything they
 * have in common lives once in ./serve.js.
 */

import { FAVICON } from './favicon.js';
import { geo } from './geo.js';
import { site as isoSite } from './iso.js';
import { site as packagesSite } from './packages.js';
import { handler } from './serve.js';
import { archiveMonth, closedMonth } from './stats.js';

// The prefix a path has to carry to reach a bucket. Anything else is the
// landing page, which the assets binding serves.
const MOUNTS = [
  { prefix: '/packages/', site: packagesSite },
  { prefix: '/iso/', site: isoSite },
];

/**
 * The site a path belongs to and the path within it, or null for the docs.
 *
 * The mount prefix is stripped here rather than inside each site, so a
 * site's resolveKey sees the same path it would have seen under its own
 * hostname - which is what lets the bucket keys stay unprefixed.
 */
export function mountFor(pathname) {
  for (const { prefix, site } of MOUNTS) {
    // `/iso` with no trailing slash is the index of that mount, not a
    // miss: a link to it would otherwise 404 into the landing page
    if (pathname === prefix.slice(0, -1)) return { site, path: '/' };
    if (pathname.startsWith(prefix)) return { site, path: pathname.slice(prefix.length - 1) };
  }
  return null;
}

/**
 * Rewrite a request onto the path its site expects.
 *
 * The site handlers read `new URL(request.url).pathname`, so the mount
 * prefix has to come off the URL itself rather than be passed alongside.
 */
function rebase(request, path) {
  const url = new URL(request.url);
  url.pathname = path;
  return new Request(url, request);
}

export default {
  /**
   * Fold the month that just closed into kv, before analytics engine
   * forgets it - it retains three months, kv keeps this for good.
   *
   * The month comes from the trigger time rather than from "now", so a
   * late or re-run invocation archives the same month instead of drifting
   * onto the wrong one.
   */
  async scheduled(event, env, ctx) {
    if (!env.ANALYTICS_TOKEN || !env.STATS) return;
    ctx.waitUntil(archiveMonth(env, closedMonth(event.scheduledTime)));
  },

  fetch(request, env, ctx) {
    const { pathname } = new URL(request.url);

    // Ahead of the docs binding, which otherwise answers for everything
    // outside a mount. The desktop reads this instead of telling a third
    // party its IP address; nothing about the request is logged or stored.
    if (pathname === '/geo') return geo(request);

    // The signing key at the root as well as under the repository: a
    // machine trusts the key before it has a repository configured, and
    // this is the URL the documentation can give for that.
    if (pathname === '/gpg-public-key.asc') {
      return packagesSite.routes['manjaro-sway.gpg'](request, env[packagesSite.bucket], env);
    }

    // At the root, because that is where every rendered page links it.
    // Under a mount it would be a bucket key, and the docs binding would
    // answer 404 for the one path all of them use.
    if (pathname === '/favicon.svg' || pathname === '/favicon.ico') {
      // .ico callers accept an svg body, so one file serves both
      return new Response(FAVICON, {
        headers: {
          'content-type': 'image/svg+xml',
          'cache-control': 'public, max-age=86400',
        },
      });
    }

    const mount = mountFor(pathname);
    if (!mount) return env.DOCS.fetch(request);
    return handler(mount.site)(rebase(request, mount.path), env, ctx);
  },
};
