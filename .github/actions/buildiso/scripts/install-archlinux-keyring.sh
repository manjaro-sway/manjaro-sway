#!/usr/bin/env bash
# Install archlinux-keyring, resolved from a repository database.
#
# The obvious source, https://archlinux.org/packages/.../download, is an
# HTML redirector rather than a mirror path, and the least reliable url in
# the action: measured by hand it answers 502 for one request in three,
# which is enough to fail check-sources on an unrelated pull request.
#
# A repository database gives the current filename, and the package sits
# beside it on the same mirror - a real mirror path, and one already
# trusted for the build itself.
set -euo pipefail

# shellcheck source=scripts/retry.sh
. "$(dirname "${BASH_SOURCE[0]}")/retry.sh"

# The build mirror first, since it is the one the build already depends on;
# an Arch mirror after it, so a single mirror lagging or dropping out does
# not stop a build. Both carry core, only under different layouts.
readonly BRANCH="${BRANCH:-stable}"
readonly REPOS=(
  "${BUILD_MIRROR:-https://forksystems.mm.fcix.net/manjaro}/${BRANCH}/core/x86_64"
  "https://geo.mirror.pkgbuild.com/core/os/x86_64"
)

fetch_keyring() {
  local repo="$1" db filename
  db="$(mktemp)"

  if ! retry curl -sfL --connect-timeout 30 -o "$db" "${repo}/core.db"; then
    rm -f "$db"
    return 1
  fi

  # %FILENAME% is the line after the marker in the package's desc entry
  filename="$(tar xzOf "$db" --wildcards 'archlinux-keyring-*/desc' 2>/dev/null |
    awk '/^%FILENAME%$/{getline; print; exit}')"
  rm -f "$db"

  if [ -z "$filename" ]; then
    echo "## keyring: ${repo}/core.db carries no archlinux-keyring" >&2
    return 1
  fi

  echo "## keyring: ${filename} from ${repo}"
  retry curl -sfL --connect-timeout 30 -o /tmp/archlinux-keyring.tar.zst \
    "${repo}/${filename}"
}

served=""
for repo in "${REPOS[@]}"; do
  if fetch_keyring "$repo"; then
    served=1
    break
  fi
  echo "## keyring: ${repo} did not serve it, trying the next mirror" >&2
done

if [ -z "$served" ]; then
  echo "## keyring: no mirror served archlinux-keyring" >&2
  exit 1
fi

# --strip-components=4 drops usr/share/pacman/keyrings/ from the paths
tar --use-compress-program=unzstd --strip-components=4 --wildcards \
  -xf /tmp/archlinux-keyring.tar.zst 'usr/share/pacman/keyrings/*'
sudo install -m0644 archlinux.gpg /usr/share/pacman/keyrings/
sudo install -m0644 archlinux-trusted /usr/share/pacman/keyrings/
sudo install -m0644 archlinux-revoked /usr/share/pacman/keyrings/
