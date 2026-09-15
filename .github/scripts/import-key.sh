#!/usr/bin/env bash
# Put the signing key in the keyring makepkg and repo-add will use.
#
# makepkg signs as the unprivileged builder, so the key has to land in that
# user's keyring rather than root's; publish runs as root, so it needs both.
set -euo pipefail

: "${GPG_SECRET_BASE64:?the signing key must be provided}"
: "${GPG_KEYID:?the key id must be provided}"

import_for() {
  local home="$1" user="${2:-}"
  local run=(env "GNUPGHOME=$home")
  [[ -n $user ]] && run=(sudo -u "$user" env "GNUPGHOME=$home")

  install -d -m 700 ${user:+-o "$user" -g "$user"} "$home"
  # --batch so a passphrase-less key imports without a tty, which a runner
  # does not have
  base64 -d <<<"$GPG_SECRET_BASE64" | "${run[@]}" gpg --batch --import
  # ultimate trust, or makepkg --sign refuses the key it just imported
  "${run[@]}" gpg --batch --command-fd 0 --edit-key "$GPG_KEYID" trust quit <<<$'5\ny\n'
}

# $HOME/.gnupg, not /root/.gnupg: a job in a container runs as root but
# with HOME=/github/home, so gpg - and therefore makepkg and repo-add -
# reads a keyring that an import into /root/.gnupg never touches. That
# failed with "The key ... does not exist in your keyring" after the import
# had reported success.
import_for "${HOME:-/root}/.gnupg"

# The publish container has no builder user - nothing there runs makepkg -
# and under `set -e` a bare `id builder && ...` makes its absence the
# script's exit status. Publishing then failed with 28 packages collected
# and the key already imported.
if id builder >/dev/null 2>&1; then
  import_for /home/builder/.gnupg builder
fi
