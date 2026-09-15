#!/usr/bin/env bash
# Download one package for pacman, trying every configured mirror.
#
# manjaro-tools points every chroot at a single mirror: mkchroot rewrites
# `Include = /etc/pacman.d/mirrorlist` to one `Server =` line built from
# build_mirror, and chroot-run overwrites the mirrorlist outright. So a
# mirrorlist with several servers in it does not survive, and pacman has
# nothing to fall back to when that one mirror stalls:
#
#   error: failed retrieving file 'linux618-6.18.49-1-x86_64.pkg.tar.zst'
#     from opencolo.mm.fcix.net : Operation too slow.
#     Less than 1 bytes/sec transferred the last 10 seconds
#   warning: too many errors from opencolo.mm.fcix.net, skipping for the
#     remainder of this transaction
#
# That killed four of fifteen editions in one run, each about twenty-five
# minutes in. XferCommand is the one hook that survives the rewrite, since
# it lives in [options] rather than in a repository section - so the
# failover goes here, swapping the host in the url pacman asks for.
#
# Usage, from pacman.conf: XferCommand = /path/pacman-xfer.sh %o %u
set -uo pipefail

readonly OUT="$1"
readonly URL="$2"

# Written by the action next to this script: one mirror base per line,
# the primary first. Absent or empty means there is nothing to fail over
# to, and the url is fetched as pacman asked for it.
MIRRORS_FILE="${PACMAN_XFER_MIRRORS:-$(dirname "${BASH_SOURCE[0]}")/build-mirrors}"

# --continue resumes a part-file from an earlier attempt; --speed-limit
# with --speed-time is what turns a stalled transfer into a failure this
# script can act on, rather than one that hangs until pacman gives up.
#
# The connect timeout was 5s, chosen when a dead mirror cost it on every
# one of ~800 invocations. The sick list below means it is now paid once
# per mirror per five minutes, so it can afford to be generous - and it
# has to be: a healthy mirror that is briefly slow to accept a connection
# is not a dead one, and 5s was low enough that one blip failed a build
# (release run 34197756772, a single 5002ms timeout with fourteen other
# editions building against that same mirror at that same moment).
curl_opts=(
  --location --fail --silent --show-error
  --continue-at -
  --connect-timeout "${PACMAN_XFER_CONNECT_TIMEOUT:-15}"
  --speed-limit "${PACMAN_XFER_SPEED_LIMIT:-10000}"
  --speed-time "${PACMAN_XFER_SPEED_TIME:-20}"
)

fetch() {
  # a part-file left by a failed attempt may be truncated at a stall, and
  # --continue-at - on a different mirror would resume into it; only reuse
  # it for a retry against the same host
  curl "${curl_opts[@]}" -o "$OUT" "$1"
}

if [ ! -s "$MIRRORS_FILE" ]; then
  fetch "$URL"
  exit $?
fi

# pacman asks for <mirror-base>/<branch>/<repo>/<arch>/<file>; the part
# after the primary's base is what gets appended to each alternative
primary="$(head -n1 "$MIRRORS_FILE")"
suffix="${URL#"${primary%/}"}"

if [ "$suffix" = "$URL" ]; then
  # not a url this script knows how to redirect - a package from a custom
  # repo, say. Fetch what pacman asked for and let it judge the result.
  fetch "$URL"
  exit $?
fi

readonly SICK_DIR="${PACMAN_XFER_SICK_DIR:-$(dirname "$MIRRORS_FILE")/sick}"
readonly SICK_TTL="${PACMAN_XFER_SICK_TTL:-300}"

sick() {
  local marker="$SICK_DIR/$(echo "$1" | tr -c 'a-zA-Z0-9' '_')"
  [ -f "$marker" ] || return 1
  local age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || echo 0) ))
  if [ "$age" -ge "$SICK_TTL" ]; then
    rm -f "$marker"
    return 1
  fi
  return 0
}

mark_sick() {
  mkdir -p "$SICK_DIR" 2>/dev/null || return 0
  : > "$SICK_DIR/$(echo "$1" | tr -c 'a-zA-Z0-9' '_')" 2>/dev/null || true
}

unmark_sick() {
  rm -f "$SICK_DIR/$(echo "$1" | tr -c 'a-zA-Z0-9' '_')" 2>/dev/null || true
}

case "$URL" in
  *.sig)
    # pacman probes for a detached signature that our repositories do not
    # publish, and treats its absence as an answer. Asking every mirror for
    # it would spend four round trips to learn the same 404, so a signature
    # is fetched from the primary only - but a *transport* failure has to
    # fail over like anything else. Skipping that is what failed release
    # run 34209674899: a .sig request to a black-holed primary burned the
    # full timeout, logged nothing, marked nothing, and failed the
    # transaction while the failover sat unused one line above.
    #
    # A mirror already known to be down is not asked at all, and a
    # transport failure falls through to the loop below; only an answer
    # (including a 404) is accepted as final.
    if ! sick "$primary"; then
      fetch "$URL"
      status=$?
      case $status in
        0|22)
          exit $status
          ;;
      esac
      mark_sick "$primary"
      echo "## xfer: ${primary} failed with exit ${status} on a signature, trying the next mirror" >&2
    else
      echo "## xfer: skipping ${primary} for the signature, marked down within the last ${SICK_TTL}s" >&2
    fi
    ;;
esac

# Each package is a separate invocation of this script - pacman runs
# XferCommand once per file, ~800 times for a desktop transaction - so a
# mirror that is down would otherwise cost its connect timeout every time.
# At 15s that is hours of waiting, and pacman gives up long before. A
# mirror that fails is recorded here and skipped by the invocations that
# follow, until the marker ages out and it gets another chance.


status=1
tried=0
while read -r mirror; do
  [ -n "$mirror" ] || continue
  if sick "$mirror"; then
    echo "## xfer: skipping ${mirror}, marked down within the last ${SICK_TTL}s" >&2
    continue
  fi
  tried=$((tried + 1))
  candidate="${mirror%/}${suffix}"

  # Mark before attempting, not after, so a mirror being probed right now
  # counts as suspect for anything else that reads the list. pacman itself
  # never runs this concurrently - an XferCommand is invoked one file at a
  # time whatever ParallelDownloads says, measured at 88 invocations with
  # no two overlapping - so this guards only against a second pacman, of
  # which a buildiso run has several in sequence.
  #
  # The marker is removed again on success, so a healthy mirror is not left
  # looking sick by its own download.
  mark_sick "$mirror"

  fetch "$candidate"
  status=$?
  if [ "$status" -eq 0 ]; then
    unmark_sick "$mirror"
    exit 0
  fi

  # a stalled mirror leaves a partial file; the next mirror must not
  # resume into it
  rm -f "$OUT"

  # 22 is an HTTP error from a mirror that answered - the file is missing
  # there, which says nothing about the mirror's health. Only a transport
  # failure (timeout, refused, reset) means "do not come back for a while",
  # so an answering mirror gets its pre-emptive marker taken back.
  if [ "$status" -eq 22 ]; then
    unmark_sick "$mirror"
  fi
  echo "## xfer: ${mirror} failed with exit ${status}, trying the next mirror" >&2
done < "$MIRRORS_FILE"

if [ "$tried" -eq 0 ]; then
  # Every mirror is marked sick. Clear the markers and take one honest run
  # through the list rather than failing without having tried anything.
  #
  # Clearing on every invocation would undo the sick list exactly when it
  # matters most - with all mirrors down, all ~800 remaining packages would
  # each re-probe every mirror. So the retry is rate limited: one sweep per
  # TTL, marked by a stamp that survives the clear.
  #
  # It says so out loud, too. Silently retrying meant a build that died on
  # this path showed one curl error and no '## xfer:' line at all, which
  # reads exactly like a failover that never ran.
  sweep="$SICK_DIR/.last-sweep"
  if [ -f "$sweep" ] &&
     [ $(( $(date +%s) - $(stat -c %Y "$sweep" 2>/dev/null || echo 0) )) -lt "$SICK_TTL" ]; then
    echo "## xfer: every mirror is marked down, and one sweep already failed within ${SICK_TTL}s" >&2
    echo "## xfer: no mirror served ${suffix#/}" >&2
    exit "$status"
  fi
  echo "## xfer: every mirror is marked sick; clearing and retrying once" >&2
  rm -rf "$SICK_DIR"
  mkdir -p "$SICK_DIR" 2>/dev/null || true
  : > "$sweep" 2>/dev/null || true
  while read -r mirror; do
    [ -n "$mirror" ] || continue
    fetch "${mirror%/}${suffix}"
    status=$?
    [ "$status" -eq 0 ] && exit 0
    rm -f "$OUT"
    # mark again: the clear above removed the markers, and without this the
    # next invocation finds nothing sick and pays the full probe again
    if [ "$status" -ne 22 ]; then
      mark_sick "$mirror"
    else
      unmark_sick "$mirror"
    fi
    echo "## xfer: ${mirror} failed with exit ${status} on the retry" >&2
  done < "$MIRRORS_FILE"
fi

echo "## xfer: no mirror served ${suffix#/}" >&2
exit "$status"
