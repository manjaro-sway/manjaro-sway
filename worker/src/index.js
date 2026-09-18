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
import { site as isoSite } from './iso.js';
import { site as packagesSite } from './packages.js';
import { handler } from './serve.js';
import { archiveMonth, closedMonth } from './stats.js';

// The hostname the repository was served from before the move, where the
// path carries no /packages prefix: Server = https://<host>/<branch>/$arch.
// Every install made from an older ISO still has that line in its
// pacman.conf, and those machines cannot be edited from here - so the host
// keeps working, with the path rewritten onto the one tree.
// Both hostnames the repository has been served from, and both are still
// in pacman.conf somewhere: packages. shipped from 2023, pkg. before it
// (bc7f7936). pkg. had no DNS record at all until #1041 was reported -
// an install from that era could not resolve the host, which is what
// "manjaro-sway.db failed to download" looks like from the inside.
const LEGACY_PACKAGES_HOSTS = new Set([
  'packages.manjaro-sway.download',
  'pkg.manjaro-sway.download',
]);

// The branch names that are not published, and the rest of the path after
// them. Anchored, so it cannot match a key that merely contains the word.
const ALIAS_BRANCH = /^\/packages\/(?:stable|testing)\/(.*)$/;

// The same on the legacy host, where there is no /packages prefix.
const LEGACY_BRANCH = /^\/(?:unstable|testing|stable)\/(.*)$/;

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
    const { hostname, pathname } = new URL(request.url);

    // The legacy repository host. Its paths are rewritten rather than
    // redirected: pacman follows a redirect fine, but this is the hot path
    // for every existing install's `-Sy`, and a hop per object is latency
    // those machines pay for nothing. The signing key is served under it
    // too, since that is the URL their pacman.conf was set up against.
    if (LEGACY_PACKAGES_HOSTS.has(hostname)) {
      const legacy = LEGACY_BRANCH.exec(pathname);
      const within = legacy ? legacy[1] : pathname.replace(/^\//, '');
      if (within === 'manjaro-sway.gpg' || within === 'gpg-public-key.asc') {
        return packagesSite.routes['manjaro-sway.gpg'](request, env[packagesSite.bucket], env);
      }
      return handler(packagesSite)(rebase(request, `/unstable/${within}`), env, ctx);
    }

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

    // Location moved to the ashlaros deployment, and installs carry the
    // old URL in their shipped copy of geoip.sh until the settings package
    // updates - which for an abandoned machine is never. Redirecting keeps
    // those desktops working instead of handing them a 404 they can only
    // fall back from. Both callers follow redirects: geoip.sh curls with
    // -L, and python-requests does by default.
    //
    // 302, not the 301 below: a permanent redirect is cached by the client
    // forever, so it could not be repointed if that deployment moves.
    //
    // Only /geo. There is no /weather on either side - this one 404s today
    // and so does ashlaros's, because weather.py calls MET Norway itself
    // and always has. Redirecting it would turn our own 404 into a hop to
    // somebody else's.
    if (pathname === '/geo') {
      return Response.redirect('https://ashlaros.download/geo', 302);
    }

    // Only unstable is published. The other two names redirect rather than
    // serving the same objects quietly: a client configured for stable was
    // getting unstable packages with nothing to say so, in its output or
    // in ours. A 301 is visible in `pacman -Sy`, and pacman follows it.
    const alias = ALIAS_BRANCH.exec(pathname);
    if (alias) {
      const url = new URL(request.url);
      url.pathname = `/packages/unstable/${alias[1]}`;
      return Response.redirect(url.toString(), 301);
    }

    const mount = mountFor(pathname);
    if (!mount) return env.DOCS.fetch(request);
    return handler(mount.site)(rebase(request, mount.path), env, ctx);
  },
};
