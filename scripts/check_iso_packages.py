#!/usr/bin/env python3
"""Fail if the ISO profile names a package nothing can install.

buildiso resolves every name in `iso-profiles/community/sway/Packages-*`
against Manjaro's repositories plus our own, and a name that resolves
nowhere fails the build - an hour in, after pacman has already downloaded
most of an image. The same answer is a few seconds of database reads here.

It also catches the opposite mistake, which fails nothing and is worse: a
package dropped from `packages/` but still listed keeps building as long as
Manjaro happens to carry a package of that name, silently swapping ours for
theirs.

The markers are manjaro-tools' own (lib/util.sh, load_pkgs): `>extra` and
`>basic` select image scope, `>multilib`/`>x86_64` select architecture,
`KERNEL` is substituted, `#` starts a comment. This reads the lists the way
a full x86_64 build does, which is the build we publish.
"""

import argparse
import io
import re
import sys
import tarfile
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = ROOT / "packages"
PROFILE = ROOT / "iso-profiles" / "community" / "sway"
SHARED = ROOT / "iso-profiles" / "shared"

MIRROR = "https://opencolo.mm.fcix.net/manjaro"
BRANCH = "unstable"
REPOSITORIES = ("core", "extra", "multilib")

# A full x86_64 build takes these and drops the rest; `>cleanup` and
# `>blacklist` name packages removed from the image rather than added.
KEPT = ("extra", "basic", "multilib", "x86_64", "manjaro")
DROPPED = ("cleanup", "blacklist", "sonar", "office", "nonfree_default",
           "nonfree_i686", "nonfree_x86_64", "nonfree_multilib")

MARKER = re.compile(r">(\w+)")

PROVIDES_RE = re.compile(r"^provides=\((.*?)\)", re.MULTILINE | re.DOTALL)

sys.path.insert(0, str(ROOT / "scripts"))
# the one implementation that resolves `pkgname=${_pkgname}` and an array
# of one; a second copy here read sway-services as the literal "${_pkgname}"
from discover_packages import pkgname_of  # noqa: E402


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def wanted(path: Path, kernel: str) -> list[tuple[str, str | None]]:
    """(name, repository) for every package a full x86_64 build installs.

    The repository is the `repo/name` qualifier when the list carries one,
    which is how the profile pins a package to our own repository rather
    than whichever tree happens to provide the name.
    """
    names = []
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue

        marker = MARKER.match(line)
        if marker:
            if marker.group(1) in DROPPED:
                continue
            if marker.group(1) not in KEPT:
                raise SystemExit(f"{path.name}: unknown marker >{marker.group(1)}")
            line = line[marker.end():].strip()

        name = line.replace("KERNEL", kernel).split()[0]
        repository, _, bare = name.rpartition("/")
        names.append((bare, repository or None))
    return names


def ours() -> dict[str, str]:
    """{name: package directory} for everything this repository builds.

    provides= counts: manjaro-sway-settings provides manjaro-desktop-settings,
    and a list naming the latter resolves against us.
    """
    built = {}
    for pkgbuild in sorted(PACKAGES.glob("*/PKGBUILD")):
        text = pkgbuild.read_text()
        directory = pkgbuild.parent.name
        built[pkgname_of(pkgbuild, text)] = directory
        provides = PROVIDES_RE.search(text)
        if provides:
            for name in provides.group(1).split():
                # a versioned provide is name=version
                built[name.strip("'\"").split("=")[0]] = directory
    return built


def manjaro() -> set[str]:
    """Every package name Manjaro's own repositories resolve, provides included."""
    names: set[str] = set()
    for repository in REPOSITORIES:
        url = f"{MIRROR}/{BRANCH}/{repository}/x86_64/{repository}.db.tar.gz"
        request = urllib.request.Request(
            url, headers={"User-Agent": "manjaro-sway-check-iso-packages"}
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                payload = response.read()
        except (urllib.error.URLError, TimeoutError) as exc:
            raise SystemExit(f"could not read {url}: {exc}")

        with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as tar:
            for member in tar.getmembers():
                if not member.name.endswith("/desc"):
                    continue
                handle = tar.extractfile(member)
                if handle is None:
                    continue
                fields = handle.read().decode(errors="replace").split("\n\n")
                for field in fields:
                    head, _, body = field.partition("\n")
                    if head == "%NAME%":
                        names.add(body.strip())
                    elif head == "%PROVIDES%":
                        for provided in body.split():
                            names.add(provided.split("=")[0])
        log(f"{repository}: {len(names)} name(s) so far")
    return names


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--kernel", default="linux612", help="the kernel the ISO is built with"
    )
    args = parser.parse_args()

    lists = sorted(PROFILE.glob("Packages-*")) + sorted(SHARED.glob("Packages-*"))
    if not lists:
        raise SystemExit(f"no package lists under {PROFILE.relative_to(ROOT)}")

    overlay = ours()
    available = manjaro()

    missing = []
    shadowed = []
    for path in lists:
        for name, repository in wanted(path, args.kernel):
            where = path.relative_to(ROOT)
            if repository and repository not in ("core", "extra", "multilib"):
                # qualified to our repository: it has to be ours, or the
                # build installs nothing under that name at all
                if name not in overlay:
                    missing.append(f"{where}: {repository}/{name} is not built here")
                continue
            if name in overlay:
                continue
            if name not in available:
                missing.append(f"{where}: {name} resolves nowhere")

    # Not fatal: a name we build and Manjaro also carries resolves either
    # way, and which one wins is user-repos.conf's ordering. Worth saying,
    # because carrying a package Manjaro already ships is work for nothing.
    for name, directory in sorted(overlay.items()):
        if name in available:
            shadowed.append(f"packages/{directory} builds {name}, which Manjaro also ships")

    for line in shadowed:
        log(f"note: {line}")
    for line in missing:
        log(f"error: {line}")

    if missing:
        return 1

    total = sum(len(wanted(path, args.kernel)) for path in lists)
    log(f"all {total} listed package(s) resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main())
