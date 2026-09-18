#!/usr/bin/env python3
"""The version a package we author should carry, derived from its history.

A package whose content lives in this repository has no upstream release to
take a version from, and a hardcoded one is worse than none: publishing an
edited payload at an unchanged pkgver means `pacman -Syu` sees the same
version and does nothing, so the edit reaches nobody. Verified - installing
one build, publishing a second with different content at the same version,
and running -Syu leaves the first in place.

So the version is computed:

    pkgver = the date of the last commit touching the package directory
    pkgrel = how many commits have touched it, ever

Both only ever increase, which is what pacman needs to see an upgrade. The
date carries meaning for a human reading `pacman -Q`; the count breaks ties
within a day and cannot reset, unlike a per-day counter.

Vendored packages are excluded: theirs come from upstream, and overwriting
them would fight the AUR's own versioning.

Needs full history - `actions/checkout` must run with fetch-depth: 0, or
every count is 1.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Only packages whose content is authored here. Everything else builds
# from an external source that carries its own version - including the
# handful with no upstream PKGBUILD to track, like laptop-mode-tools,
# whose pkgver is the upstream release it fetches.
AUTHORED_PREFIX = "manjaro-sway-"


SOURCE_TREES_RE = re.compile(r"^_source_trees=\((.*?)\)", re.MULTILINE | re.DOTALL)


class NoHistory(Exception):
    """The checkout carries no usable git history."""


def source_trees(directory: Path) -> list[str]:
    """Extra directories the package is built from, as declared in its PKGBUILD.

    A package whose content lives outside its own directory says so here.
    Counting commits to the package directory alone would leave the version
    unchanged when that content changes, and pacman treats equal versions
    as nothing to do - so the edit would reach nobody.
    """
    declared = SOURCE_TREES_RE.search((directory / "PKGBUILD").read_text())
    if not declared:
        return []
    return [name.strip("\"'") for name in declared.group(1).split()]


def git(*args: str) -> str:
    result = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True)
    if result.returncode != 0:
        # not a repository, or a checkout without history. Failing loudly
        # beats inventing a version: a wrong one either strands an update
        # or overwrites a published package.
        raise NoHistory(result.stderr.strip() or "git failed")
    return result.stdout.strip()


def version_of(directory: Path) -> tuple[str, str] | None:
    """(pkgver, pkgrel) for a package directory, or None if not ours."""
    if not directory.name.startswith(AUTHORED_PREFIX):
        return None

    paths = [directory.relative_to(ROOT).as_posix(), *source_trees(directory)]
    count = git("rev-list", "--count", "HEAD", "--", *paths)
    date = git("log", "-1", "--format=%cd", "--date=format:%Y%m%d", "--", *paths)

    # a shallow clone reports 1 for everything, which would publish every
    # authored package at pkgrel=1 forever and strand every later update
    if count == "1" and git("rev-parse", "--is-shallow-repository") == "true":
        raise NoHistory(
            "shallow checkout: package versions need full history "
            "(actions/checkout with fetch-depth: 0)"
        )

    if not date or count == "0":
        # never committed - a new package in a dirty tree
        return None
    return date, count


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <package directory>", file=sys.stderr)
        return 2

    directory = Path(sys.argv[1]).resolve()
    try:
        version = version_of(directory)
    except NoHistory as exc:
        print(f"{directory.name}: {exc}", file=sys.stderr)
        return 2
    if version is None:
        return 1

    print(f"{version[0]}-{version[1]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
