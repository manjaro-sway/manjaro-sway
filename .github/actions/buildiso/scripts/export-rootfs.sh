#!/usr/bin/env bash
# Export the ISO's squashfs layers as a flat rootfs tarball, ready to be
# turned into an OCI image.
#
# An ISO is not a container image: it carries a kernel, an initramfs, a
# bootloader and an installer, and it is booted rather than run. The
# desktop inside it, though, is exactly what a container wants - and
# manjaro-tools already builds that desktop as a stack of squashfs layers
# which calamares unpacks onto the target with no translation:
#
#   rootfs.sfs     the base system
#   desktopfs.sfs  the desktop on top of it
#   livefs.sfs     the live session - autologin, branding, the live user
#
# Stacking the same layers in the same order gives the filesystem a user
# gets after installing, without booting anything. What is dropped is what
# only a boot needs: the kernel, its modules, the initramfs and the
# installer.
#
# The mhwd layer is deliberately not included. It is a package repository
# for hardware drivers, not part of the running system.
set -euo pipefail

usage() {
  echo "usage: ${0##*/} --work-dir DIR --output FILE [--keep-installer]" >&2
  echo >&2
  echo "  --work-dir  manjaro-tools build dir holding the *.sfs layers" >&2
  echo "  --output    tarball to write" >&2
  echo "  --keep-installer  leave calamares in place" >&2
  exit 1
}

WORK_DIR=""
OUTPUT=""
KEEP_INSTALLER="false"

while [ $# -gt 0 ]; do
  case "$1" in
    --work-dir) WORK_DIR="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --keep-installer) KEEP_INSTALLER="true"; shift ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

[ -n "$WORK_DIR" ] && [ -n "$OUTPUT" ] || usage

# The layers, in the order calamares unpacks them: later ones win.
readonly LAYERS=(rootfs desktopfs livefs)

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

found=0
for layer in "${LAYERS[@]}"; do
  sfs="$(find "$WORK_DIR" -name "${layer}.sfs" -print -quit 2>/dev/null || true)"
  if [ -z "$sfs" ]; then
    # a minimal profile has no desktopfs, and that is not an error
    echo "## rootfs: no ${layer}.sfs, skipping" >&2
    continue
  fi
  echo "## rootfs: unpacking ${layer}.sfs onto the stack"
  # -f so a later layer overwrites the earlier one, which is the whole
  # point of the stack; -no-xattrs because a tarball carries its own
  unsquashfs -f -no-progress -dest "$root" "$sfs" >/dev/null
  found=$((found + 1))
done

if [ "$found" -eq 0 ]; then
  echo "## rootfs: no squashfs layers under $WORK_DIR" >&2
  exit 1
fi

echo "## rootfs: dropping what only a boot needs"
# The kernel and its modules are the bulk of it, and a container never
# uses them: it runs on the host's kernel.
rm -rf "$root"/boot
rm -rf "$root"/lib/modules "$root"/usr/lib/modules
rm -rf "$root"/lib/firmware "$root"/usr/lib/firmware
rm -f  "$root"/etc/mkinitcpio.conf
rm -rf "$root"/etc/mkinitcpio.d

if [ "$KEEP_INSTALLER" = "false" ]; then
  # calamares installs onto a disk, which is meaningless here and invites
  # a visitor to try
  rm -rf "$root"/usr/share/calamares "$root"/etc/calamares
  rm -f  "$root"/usr/bin/calamares
  find "$root"/usr/share/applications -name '*calamares*' -delete 2>/dev/null || true
  find "$root"/etc/xdg/autostart -name '*calamares*' -delete 2>/dev/null || true
fi

# A container gets its resolver from the runtime; a copied one points at
# whatever the builder used.
rm -f "$root"/etc/resolv.conf

# The package cache is a build artifact, and it is large.
rm -rf "$root"/var/cache/pacman/pkg/*
rm -rf "$root"/var/lib/pacman/sync/*

# /dev is provided by the runtime, and a tarball of device nodes needs
# privileges to unpack that a registry push should not require.
rm -rf "$root"/dev
mkdir -p "$root"/dev

echo "## rootfs: $(du -sh "$root" | cut -f1) after pruning"

# --numeric-owner keeps uids as they are rather than mapping them through
# the builder's passwd; --xattrs preserves capabilities that setuid-less
# binaries rely on, e.g. ping.
tar --numeric-owner --xattrs --acls \
    -C "$root" -c . | zstd -T0 -19 -o "$OUTPUT" -f

echo "## rootfs: wrote $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
