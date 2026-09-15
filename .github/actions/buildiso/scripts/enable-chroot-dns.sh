#!/usr/bin/env bash
# Give the buildiso chroots a resolver.
#
# buildiso reaches its chroots through mkchroot -> basestrap, which copies
# the host keyring and mirrorlist but not /etc/resolv.conf, and mounts the
# API filesystems with the chroot_api_mount variant that carries no
# resolv.conf bind - unlike chroot-run, used for package builds, which does.
#
# So every chroot resolves nothing: pacman-mirrors cannot rank mirrors and
# falls back to a random mirrorlist, and post-install scriptlets that fetch
# anything fail. Both are silent - the build still succeeds.
#
# The resolver must exist *before* basestrap installs anything: the
# packages' own post-install hooks need it. pacman-mirrors runs as hook
# (24/26) during installation and is what reports "Internet connection
# appears to be down", so writing the file after chroot_create returns -
# as this script first did - is already too late.
#
# mkchroot creates $working_dir and then calls basestrap, so the resolver
# goes in between. That covers every overlay (rootfs, desktopfs, livefs,
# mhwdfs) because they all reach basestrap through mkchroot.
#
# Idempotent: safe to run more than once.
set -euo pipefail

MKCHROOT=${MKCHROOT_BIN:-/usr/bin/mkchroot}

[ -f "$MKCHROOT" ] || { echo "not found: $MKCHROOT" >&2; exit 1; }

if grep -q 'chroot dns' "$MKCHROOT"; then
  echo "chroot dns already enabled"
  exit 0
fi

python3 - "$MKCHROOT" "${CHROOT_NAMESERVERS:-1.1.1.1 8.8.8.8}" <<'EOF'
import pathlib
import sys

path, nameservers = pathlib.Path(sys.argv[1]), sys.argv[2].split()
text = path.read_text()

# both basestrap calls are guarded by the same branch, so inserting before
# the enclosing `if` covers whichever one runs
anchor = "# Workaround when creating a chroot in a branch different of the host"
if anchor not in text:
    raise SystemExit("mkchroot is not in the expected shape")

lines = "".join(
    f'printf \'nameserver {ns}\\n\' >> "$working_dir/etc/resolv.conf"\n'
    for ns in nameservers
)
inject = f"""# chroot dns: package hooks resolve names during installation - notably
# pacman-mirrors, which otherwise reports the connection as down and
# randomises the mirrorlist - and basestrap copies no resolver in
install -Dm644 /dev/null "$working_dir/etc/resolv.conf"
{lines}
{anchor}"""
path.write_text(text.replace(anchor, inject, 1))
EOF

grep -q 'chroot dns' "$MKCHROOT" || { echo "patch did not apply" >&2; exit 1; }
echo "chroot dns enabled"
