#!/usr/bin/env python3
"""Rank Manjaro mirrors by how fast they are *from here*, and rewrite action.yml.

A mirror benchmarked from a laptop tells you about the laptop's link, not
about the runner's. opencolo measured 12.8 MB/s from Germany and 33-48
MiB/s from a GitHub runner, which is enough to invert a ranking. So this
runs on a runner and nowhere else.

It picks the primary and the fallbacks together, because they are one
decision: four mirrors, ordered, from operators that are not all the same
machine room.

Sync state is a gate, not a score. A mirror that lags is disqualified
however fast it is; among those in sync, throughput decides.
"""

import argparse
import json
import re
import statistics
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

STATUS_URL = "https://repo.manjaro.org/status.json"

# Enough to leave TCP slow start behind - a few hundred KB measures the
# handshake, not the transfer. Capped because this runs against a dozen
# mirrors and the runner is not free.
SAMPLE_BYTES = 64 * 1024 * 1024
CONNECT_TIMEOUT = 10
READ_TIMEOUT = 60

# The file every mirror is asked for. It has to be big enough that the
# transfer dominates the handshake - core.db is 154 KB, which measures
# round trips and ranks mirrors by latency rather than bandwidth. The
# kernel is tens of megabytes, present on every mirror, and is exactly the
# kind of file a build spends its time on. Resolved from core.db at run
# time so a version bump does not silently 404 the whole benchmark.
PROBE_REPO = "stable/core/x86_64"
PROBE_PREFIX = "linux"


def log(msg: str) -> None:
    print(msg, file=sys.stderr, flush=True)


def candidates(limit: int) -> list[str]:
    """Mirrors carrying every branch, https, sorted by how recently synced."""
    with urllib.request.urlopen(STATUS_URL, timeout=30) as resp:
        status = json.load(resp)

    fresh = [
        m
        for m in status
        if all(b == 1 for b in m.get("branches", []))
        and "https" in m.get("protocols", [])
    ]
    # last_sync is HH:MM since the last successful sync, so string order is
    # time order for anything under a day
    fresh.sort(key=lambda m: m.get("last_sync", "99:99"))
    log(f"  {len(fresh)} mirror(s) carry all three branches over https")
    return [m["url"].rstrip("/") for m in fresh[:limit]]


def probe_path(base: str) -> str | None:
    """A kernel package this mirror actually carries, from its own core.db."""
    import io
    import tarfile

    try:
        with urllib.request.urlopen(f"{base}/{PROBE_REPO}/core.db", timeout=30) as resp:
            payload = resp.read()
        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as db:
            for member in db.getmembers():
                if not member.name.endswith("/desc"):
                    continue
                if not member.name.startswith(PROBE_PREFIX):
                    continue
                desc = db.extractfile(member).read().decode("utf-8", "replace")
                if "%FILENAME%" not in desc:
                    continue
                name = desc.split("%FILENAME%\n")[1].split("\n")[0]
                # skip the headers and docs split-offs; we want the kernel
                if "headers" in name or "docs" in name:
                    continue
                return f"{PROBE_REPO}/{name}"
    except (urllib.error.URLError, OSError, tarfile.TarError, IndexError):
        return None
    return None


def measure(base: str, repeats: int) -> float | None:
    """Median MB/s over `repeats` samples, or None if the mirror misbehaves."""
    probe = probe_path(base)
    if probe is None:
        log(f"  {base.split('/')[2]:34} no kernel package to measure")
        return None
    url = f"{base}/{probe}"
    rates = []
    for _ in range(repeats):
        try:
            start = time.monotonic()
            req = urllib.request.Request(url, headers={"Range": f"bytes=0-{SAMPLE_BYTES - 1}"})
            with urllib.request.urlopen(req, timeout=CONNECT_TIMEOUT) as resp:
                read = 0
                while chunk := resp.read(1 << 20):
                    read += len(chunk)
                    if time.monotonic() - start > READ_TIMEOUT:
                        break
        except (urllib.error.URLError, OSError, TimeoutError) as e:
            log(f"  {base.split('/')[2]:34} unreachable: {e}")
            return None
        elapsed = time.monotonic() - start
        if elapsed <= 0 or read == 0:
            return None
        rates.append(read / elapsed / 1e6)
    return statistics.median(rates)


def operator_of(base: str) -> str:
    """The registrable domain, as a stand-in for who runs the mirror.

    mm.fcix.net and fcix.net are one operator, and so are
    mirrors.manjaro.org and mirrors2.manjaro.org.
    """
    return ".".join(base.split("/")[2].split(".")[-2:])


def spread(ranked: list[tuple[str, float]], count: int, per_operator: int) -> list[str]:
    """The fastest `count`, taking at most `per_operator` from any one.

    Several of the fastest mirrors are one network under different names,
    and a fallback list that is four names on one network fails together -
    the one thing a fallback list must not do. But refusing a second name
    from the best network is worse: FCIX is most of what is fast from a
    runner, and excluding it to satisfy a rule would pick slow mirrors on
    principle. So cap rather than forbid, and backfill from what is left
    if the cap cannot be met.
    """
    picked: list[str] = []
    taken: dict[str, int] = {}
    for base, _rate in ranked:
        operator = operator_of(base)
        if taken.get(operator, 0) >= per_operator:
            continue
        taken[operator] = taken.get(operator, 0) + 1
        picked.append(base)
        if len(picked) == count:
            return picked

    # not enough operators to fill the list; take the next fastest rather
    # than shipping a shorter fallback chain than asked for
    for base, _rate in ranked:
        if base not in picked:
            picked.append(base)
            if len(picked) == count:
                break
    return picked


def rewrite(action: Path, primary: str, fallbacks: list[str]) -> bool:
    """Point build-mirror and fallback-mirrors at the chosen mirrors."""
    src = action.read_text()

    new_primary = re.sub(
        r"(?<=  build-mirror:\n)(.*?)(default: )\S+\n",
        lambda m: f"{m.group(1)}{m.group(2)}{primary}\n",
        src,
        count=1,
        flags=re.S,
    )
    if new_primary == src and f"default: {primary}" not in src:
        raise SystemExit("could not rewrite build-mirror")

    indented = "\n".join(f"      {f}" for f in fallbacks)
    pattern = re.compile(
        r"(?<=  fallback-mirrors:\n)(.*?default: >-\n)(?:      \S+\n)+",
        re.S,
    )
    if not pattern.search(new_primary):
        raise SystemExit("could not rewrite fallback-mirrors")
    out = pattern.sub(lambda m: f"{m.group(1)}{indented}\n", new_primary, count=1)

    if out == src:
        return False
    action.write_text(out)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action", default="action.yml", type=Path)
    parser.add_argument("--pool", type=int, default=12, help="mirrors to measure")
    parser.add_argument("--keep", type=int, default=4, help="primary plus fallbacks")
    parser.add_argument("--repeats", type=int, default=2)
    parser.add_argument(
        "--per-operator",
        type=int,
        default=2,
        help="at most this many mirrors from one operator",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    log("## candidates")
    pool = candidates(args.pool)

    log("## measuring")
    ranked: list[tuple[str, float]] = []
    for base in pool:
        rate = measure(base, args.repeats)
        if rate is None:
            continue
        log(f"  {base.split('/')[2]:34} {rate:6.1f} MB/s")
        ranked.append((base, rate))

    if len(ranked) < args.keep:
        log(f"only {len(ranked)} mirror(s) answered; refusing to narrow the list")
        return 1

    ranked.sort(key=lambda pair: pair[1], reverse=True)
    chosen = spread(ranked, args.keep, args.per_operator)

    log("## chosen")
    log(f"  primary   {chosen[0]}")
    for f in chosen[1:]:
        log(f"  fallback  {f}")

    if args.dry_run:
        return 0

    changed = rewrite(args.action, chosen[0], chosen[1:])
    log("## action.yml updated" if changed else "## already ranked this way")
    print(f"changed={'true' if changed else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
