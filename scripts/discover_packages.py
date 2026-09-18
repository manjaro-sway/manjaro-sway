#!/usr/bin/env python3
"""Decide what needs building, and in what order.

Three things shape a run:

  - `arch=any` packages build once and are registered in both databases;
    anything else builds per architecture. Read out of each PKGBUILD's own
    arch= line, so there is no second list to drift.

  - A package that depends on another package built here cannot be built in
    the same wave: the dependency has to be published before makepkg can
    resolve it. flashfocus needs python-xpybutil, and Arch packages neither.
    Wave 0 is everything with no such dependency; wave 1 is what depends on
    wave 0, and so on.

  - A package already published at the version its PKGBUILD declares is
    skipped. Rebuilding it is not free and not harmless: makepkg is not
    reproducible - two builds of one version differ in .BUILDINFO
    timestamps - so republishing replaces an object the worker serves as
    `immutable, max-age=31536000` and changes the %SHA256SUM% the database
    records for it. A client holding the cached old bytes then fails the
    checksum on install.

Skipping is by declared version AND source hash: the version alone would
miss a PKGBUILD edit that changes what gets built without touching pkgver
(wluma's dropped man-page step did exactly that, and needed pkgrel bumped
by hand). Set REBUILD_ALL=1 to ignore what is published and build
everything, which is what a toolchain change needs.

Writes GitHub Actions outputs on stdout.
"""

import hashlib
import io
import json
import os
import re
import subprocess
import sys
import tarfile
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = ROOT / "packages"

ARCH_RE = re.compile(r"^arch=\((.*?)\)", re.MULTILINE | re.DOTALL)
# depends and makedepends both have to exist before the build starts;
# optdepends do not, so they are deliberately absent here
# finditer, not search: depends= and makedepends= are two assignments, and
# taking only the first dropped every makedepends in the tree - 17 of our
# packages declare both, so their build order was computed from half their
# edges. checkdepends counts too: it is installed before makepkg runs.
DEPENDS_RE = re.compile(r"^(?:make|check)?depends=\((.*?)\)", re.MULTILINE | re.DOTALL)
PKGNAME_RE = re.compile(r"^pkgname=(.+)$", re.MULTILINE)
PKGVER_RE = re.compile(r"^pkgver=(.+)$", re.MULTILINE)
PKGREL_RE = re.compile(r"^pkgrel=(.+)$", re.MULTILINE)
EPOCH_RE = re.compile(r"^epoch=(.+)$", re.MULTILINE)
# a pinned revision makes a pkgver() deterministic
COMMIT_RE = re.compile(r"^_commit=[\"']?[0-9a-f]{40}", re.MULTILINE)
# A definition at the start of a line, not the substring "pkgver()"
# anywhere: gtk-nocsd's own comment explains why it does NOT use one, and
# matching that sentence made its version unknowable, so it was rebuilt on
# every run - the very failure the comment describes.
PKGVER_FN_RE = re.compile(r"^\s*pkgver\s*\(\)\s*\{", re.MULTILINE)

REPO_URL = os.environ.get("REPO_URL", "https://sway.manjaro.download/packages/unstable")
FIELD = re.compile(r"%([A-Z0-9]+)%\n([^\n]*)")

# What the repository records for a package we built, so a rebuild can be
# recognised as unnecessary. Not a pacman field - it goes in %PACKAGER%,
# which repo-add copies from the package and nothing else reads.
SOURCE_MARK = "manjaro-sway-src:"


def log(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def field(pattern: re.Pattern, text: str) -> list[str]:
    """Every quoted or bare word in EVERY matching array assignment.

    All of them, because depends= and makedepends= are separate lines and
    a package needs both to be ordered correctly.

    A version constraint is cut at the operator rather than split on it:
    `sqlite>=3.0` is a dependency on sqlite, and tokenising the whole
    string invented a second dependency named "3.0" - which howdy-next
    really did carry, as a phantom edge on "7.85.0".
    """
    names = []
    for match in pattern.finditer(text):
        body = re.sub(r"#.*", "", match.group(1))
        for word in body.replace("'", " ").replace('"', " ").split():
            # strip >=, <=, =, >, < and whatever follows
            name = re.split(r"[<>=]", word, maxsplit=1)[0]
            if re.fullmatch(r"[\w.+-]+", name):
                names.append(name)
    return names


def scalar(pattern: re.Pattern, text: str) -> str | None:
    """The value of a `name=value` line, without a trailing comment.

    catppuccin-gtk-theme-* carries `pkgver=1.0.3 # renovate: ...`, and
    keeping the comment made the declared version
    "1.0.3 # renovate: ...-1", which can never equal the "1.0.3-1" the
    database records - so those packages were rebuilt on every run
    forever. Harmless while a rebuild was merely wasteful; a hard failure
    once publish.py started refusing to overwrite a published object with
    different bytes, which is what makepkg produces every time (#57).
    """
    match = pattern.search(text)
    if not match:
        return None
    value = match.group(1).strip()
    # A # inside quotes is part of the value; a # after the closing quote
    # is a comment. Skipping the split entirely for a quoted value got the
    # first half right and the second half wrong: `pkgver="1.0.3" # x`
    # came back as `1.0.3" # x`, a version that can never match what the
    # database records - the same rebuild-forever failure this function
    # exists to prevent, just one quote further along.
    if value[:1] in ("'", '"'):
        quote = value[0]
        end = value.find(quote, 1)
        if end != -1:
            value = value[1:end]
        else:
            value = value[1:]
    else:
        value = value.split("#", 1)[0].strip()
    return value.strip("'\"")


def pkgname_of(pkgbuild: Path, text: str) -> str:
    """The package name a PKGBUILD produces.

    Three forms appear in ours: a plain `pkgname=swayr`, an array
    `pkgname=('nwg-wrapper')`, and an indirection `pkgname=${_pkgname}`.
    Reading the first as-is and the other two literally is what made the
    published-version lookup miss - the key was `${_pkgname}` and
    `('nwg-wrapper')`, so those two rebuilt on every run despite being
    unchanged.
    """
    raw = scalar(PKGNAME_RE, text)
    if not raw:
        return pkgbuild.parent.name

    # Substitute every variable reference, not only a value that is one
    # reference and nothing else. `pkgname=${_pkgname}-git` failed the old
    # whole-string match and then had its first word taken, which is the
    # literal string "_pkgname" - sway-services really did resolve to that.
    def resolve(match: re.Match) -> str:
        assigned = scalar(re.compile(rf"^{match.group(1)}=(.+)$", re.MULTILINE), text)
        return assigned if assigned else match.group(0)

    raw = re.sub(r"\$\{?(\w+)\}?", resolve, raw)

    # an array of one, which is how some PKGBUILDs spell a single package
    words = re.findall(r"[\w.+@-]+", raw.replace("'", " ").replace('"', " "))
    return words[0] if words else pkgbuild.parent.name


def declared_version(text: str) -> str | None:
    """The version the PKGBUILD states, or None when it cannot be known here.

    A pkgver() function resolves the version from a source checkout at build
    time, which this cannot do. It is still knowable when the sources are
    pinned to a _commit: the checkout is then always the same one, so the
    version it computes is fixed, and the pkgver= line already carries the
    result. An unpinned pkgver() - a package tracking a branch tip - is
    genuinely unknowable and never skipped.
    """
    if PKGVER_FN_RE.search(text) and not COMMIT_RE.search(text):
        return None
    pkgver = scalar(PKGVER_RE, text)
    pkgrel = scalar(PKGREL_RE, text)
    if not pkgver or not pkgrel:
        return None
    epoch = scalar(EPOCH_RE, text)
    return f"{epoch}:{pkgver}-{pkgrel}" if epoch else f"{pkgver}-{pkgrel}"


def authored_version(directory: Path) -> str | None:
    """The version a package we author will be built with.

    build-package.sh stamps this into the PKGBUILD from the package's git
    history, so the PKGBUILD on disk still carries the previous one. Asking
    the same question here is what keeps the skip honest: without it a
    payload edit would compare the OLD version against the published OLD
    version, match, and skip the very rebuild that edit needs.
    """
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "package_version.py"), str(directory)],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


SOURCE_TREES_RE = re.compile(r"^_source_trees=\((.*?)\)", re.MULTILINE | re.DOTALL)


def source_trees(directory: Path) -> list[Path]:
    """Directories a package is built from, itself first.

    A package can build from a tree outside its own directory. A PKGBUILD
    says so with _source_trees=(...); without it an edit there would change
    what the package ships while looking untouched, so the package would
    keep its version and be skipped forever.
    """
    trees = [directory]
    declared = SOURCE_TREES_RE.search((directory / "PKGBUILD").read_text())
    if declared:
        for name in declared.group(1).split():
            tree = ROOT / name.strip("\"'")
            if not tree.is_dir():
                raise SystemExit(
                    f"{directory.name}: _source_trees names {name}, which does not exist"
                )
            trees.append(tree)
    return trees


def _ships(path: Path) -> bool:
    """Whether this file is installed as-is, so its mode is part of it.

    A payload tree is copied into the package with its modes; everything
    beside it - the PKGBUILD, .install, patches - is read by makepkg and
    never installed, so its own mode says nothing about the result.
    """
    return "payload" in path.parts


def source_hash(directory: Path) -> str:
    """A digest of everything a package is built from.

    The PKGBUILD alone is not enough: manjaro-sway-settings ships its whole
    payload tree beside it, and editing one file changes the package
    without touching pkgver.
    """
    digest = hashlib.sha256()
    for tree in source_trees(directory):
        for path in sorted(p for p in tree.rglob("*") if p.is_file()):
            digest.update(path.relative_to(tree).as_posix().encode())
            # The exec bit is part of what ships, but only where we ship
            # the file: a payload script that gains +x is a different
            # package, and hashing contents alone left that rebuild
            # unscheduled. A PKGBUILD's own mode is not - it is input to
            # makepkg, never installed - and hashing it changed the mark
            # of all 26 vendored packages at once. Those take their
            # version from upstream and cannot be bumped, so each would
            # have been rebuilt, refused by the publish guard, and stuck
            # there with nothing to turn.
            if _ships(path):
                digest.update(b"x" if path.stat().st_mode & 0o111 else b"-")
            digest.update(path.read_bytes())
    return digest.hexdigest()[:16]


def published(arch: str) -> dict[str, tuple[str, str | None]]:
    """{pkgname: (version, source hash)} from the live database.

    A repository that cannot be reached yields nothing, so a run builds
    everything rather than skipping on incomplete information.
    """
    url = f"{REPO_URL}/{arch}/manjaro-sway.db.tar.gz"
    # a named User-Agent, because cloudflare's bot protection answers 403 to
    # urllib's default and a 403 here silently means "rebuild everything"
    request = urllib.request.Request(url, headers={"User-Agent": "manjaro-sway-discover-packages"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read()
    except (urllib.error.URLError, TimeoutError) as exc:
        log(f"{arch}: could not read the published database ({exc}); building everything")
        return {}

    entries = {}
    with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as tar:
        for member in tar.getmembers():
            if not member.name.endswith("/desc"):
                continue
            handle = tar.extractfile(member)
            if handle is None:
                continue
            desc = dict(FIELD.findall(handle.read().decode()))
            name, version = desc.get("NAME"), desc.get("VERSION")
            if not name or not version:
                continue
            packager = desc.get("PACKAGER", "")
            mark = None
            if SOURCE_MARK in packager:
                mark = packager.split(SOURCE_MARK, 1)[1].strip().rstrip(">")
            entries[name] = (version, mark)
    return entries


def main() -> int:
    only = os.environ.get("ONLY", "").strip()
    rebuild_all = os.environ.get("REBUILD_ALL", "").strip() not in ("", "0", "false")

    packages = {}
    for pkgbuild in sorted(PACKAGES.glob("*/PKGBUILD")):
        text = pkgbuild.read_text()
        name = pkgbuild.parent.name
        packages[name] = {
            "pkgname": pkgname_of(pkgbuild, text),
            "any": field(ARCH_RE, text) == ["any"],
            "depends": field(DEPENDS_RE, text),
            "version": authored_version(pkgbuild.parent) or declared_version(text),
            "source": source_hash(pkgbuild.parent),
        }

    if only:
        if only not in packages:
            raise SystemExit(f"no package directory named {only}")
        packages = {only: packages[only]}

    skipped = []
    if not rebuild_all and not only:
        # one tree, so an `any` package and a compiled one are judged the
        # same way: published at this version, built from this source
        live = published("x86_64")
        for name, meta in list(packages.items()):
            version, source = meta["version"], meta["source"]
            if version is None:
                continue
            if live.get(meta["pkgname"]) == (version, source):
                skipped.append(name)
                del packages[name]

    provided = {meta["pkgname"]: name for name, meta in packages.items()}

    waves = []
    remaining = dict(packages)
    built: set[str] = set()
    while remaining:
        ready = {
            name: meta
            for name, meta in remaining.items()
            # only dependencies we build in THIS run can hold a package
            # back; anything skipped is already published, and anything
            # else comes from Manjaro
            if not {provided[d] for d in meta["depends"] if d in provided and provided[d] != name}
            - built
        }
        if not ready:
            cycle = ", ".join(sorted(remaining))
            raise SystemExit(f"dependency cycle among: {cycle}")

        waves.append(
            {
                "any": sorted(n for n, m in ready.items() if m["any"]),
                "compiled": sorted(n for n, m in ready.items() if not m["any"]),
            }
        )
        built |= {m["pkgname"] for m in ready.values()}
        for name in ready:
            del remaining[name]

    if skipped:
        log(f"already published, not rebuilding: {', '.join(sorted(skipped))}")

    print(f"waves={json.dumps(waves)}")
    print(f"wave_count={len(waves)}")
    print(f"skipped={json.dumps(sorted(skipped))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
