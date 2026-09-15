#!/usr/bin/env bash
# Build and sign one package directory.
set -euo pipefail

pkg_dir="${1:?usage: build-package.sh <package directory>}"
: "${GPG_KEYID:?the key id must be provided}"

# every path below is relative to the checkout, and the build cds away
root="$PWD"

# the repository moves under us between the container's sync and this build;
# a makedepend resolved against a stale database installs a version the
# current one no longer has
pacman -Syu --noconfirm

# makepkg refuses to run as root, and the whole checkout has to be readable
# by the user it runs as instead
chown -R builder:builder .

# ...which makes git, still running as root here, refuse the checkout for
# dubious ownership - and package_version.py below needs it. Seen as
# "cannot derive a version for packages/manjaro-sway-settings".
git config --global --add safe.directory "$root"

# A package we author has no upstream release to take a version from, and a
# hardcoded one silently strands every update: publishing edited content at
# an unchanged pkgver means pacman -Syu sees the same version and does
# nothing. Stamp the version derived from the package's own git history
# instead - date of the last commit, count of all commits touching it, both
# monotonic. Vendored packages keep upstream's version and are left alone.
# Computed BEFORE the version is stamped in, because discover_packages.py
# computes it from the checkout as committed. Stamping first put a rewritten
# pkgver/pkgrel into the hashed bytes, so the mark recorded here could never
# equal the mark computed there: every authored package looked changed on
# every run, was rebuilt, and was republished at the version it already had -
# overwriting an object the worker serves as immutable, which is #57. Proved
# by hashing one PKGBUILD both ways: the stamped hash is exactly the mark the
# published database carries.
source_hash=$(cd "$root" && python3 - "$pkg_dir" <<'PYTHON'
import importlib.util, pathlib, sys

# the one implementation discovery reads back, so the two can never
# disagree about what a package was built from - a second copy here missed
# _source_trees and would have stamped a mark that never matched
spec = importlib.util.spec_from_file_location("d", "scripts/discover_packages.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.source_hash(pathlib.Path(sys.argv[1])))
PYTHON
)

version=$(python3 scripts/package_version.py "$pkg_dir") && stamp=0 || stamp=$?
case "$stamp" in
0)
  echo "## $pkg_dir: stamping version $version"
  sed -i -E "s/^pkgver=.*/pkgver=${version%-*}/; s/^pkgrel=.*/pkgrel=${version##*-}/" \
    "$pkg_dir/PKGBUILD"
  ;;
1) ;; # vendored: keeps upstream's version
*)
  # a broken or shallow checkout. Building anyway would publish a wrong
  # version, which either strands the update or overwrites a package.
  echo "::error::cannot derive a version for $pkg_dir"
  exit 1
  ;;
esac

cd "$pkg_dir"

# a PKGBUILD that verifies an upstream release signature needs that author's
# key in the builder keyring, or makepkg aborts before it starts building
keys=$(sed -n '/validpgpkeys=(/,/)/p' PKGBUILD | grep -oE '[0-9A-Fa-f]{40}' || true)
for key in $keys; do
  sudo -u builder gpg --keyserver keyserver.ubuntu.com --recv-keys "$key" ||
    echo "could not fetch $key; makepkg will report the failure"
done

# The mark recorded in PACKAGER, so a later run can tell that rebuilding
# would produce the same thing. PACKAGER is the only free-text field
# repo-add copies into the database that nothing else reads; the hash is
# over every file a package is built from - its directory plus any
# _source_trees it declares - because a payload edit changes the package
# without touching pkgver. discover_packages.py reads it back out of the
# published database.

# --nocheck: several check() suites want a network or a display a sandboxed
# runner does not have, and a package that builds but cannot self-test is
# still the package we ship.
sudo -u builder --preserve-env=GPG_KEYID \
  PACKAGER="Manjaro Sway <manjaro-sway-src:${source_hash}>" \
  makepkg -s --noconfirm --nocheck --sign --key "$GPG_KEYID"
