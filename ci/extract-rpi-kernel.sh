#!/usr/bin/env bash
# Extract kernel + initramfs from a Manjaro ARM rpi4 disk image so QEMU's
# -M virt machine can boot it (the raspi4b machine model has too many gaps).
#
# Reads the FAT32 boot partition directly with mtools — no sudo, no loop
# devices, no mount races. Side effect: drops Image and initramfs-linux.img
# next to the input image, which is what boot-smoke.sh aarch64 expects.
#
# Usage: extract-rpi-kernel.sh <image>

set -euo pipefail

IMG="${1:?image path required}"
case "$IMG" in
  *.xz)  xz --decompress --force "$IMG"; IMG="${IMG%.xz}";;
  *.zst) zstd -d --force "$IMG"; IMG="${IMG%.zst}";;
esac

OUT_DIR="$(dirname "$IMG")"

# Find the first partition's byte offset. sfdisk -d on a file works without
# sudo for owned files and gives us a stable machine-readable layout.
P1_START_SECTORS="$(sfdisk -d "$IMG" 2>/dev/null \
  | sed -n 's/^.*1[[:space:]]*:.*start=[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
  | head -n1)"
[ -n "$P1_START_SECTORS" ] || { echo "could not parse partition 1 start sector"; sfdisk -d "$IMG"; exit 1; }
P1_OFFSET=$(( P1_START_SECTORS * 512 ))

mdir_target="${IMG}@@${P1_OFFSET}"

# Names drift across kernel packages — pick the first match. mdir output
# format on the FAT32 boot partition has filenames as the first column.
KERNEL=""
for kn in Image kernel8.img kernel7l.img; do
  if mdir -i "$mdir_target" "::$kn" >/dev/null 2>&1; then
    KERNEL="$kn"
    break
  fi
done
[ -n "$KERNEL" ] || { echo "no kernel image found on boot partition"; mdir -i "$mdir_target" :: ; exit 1; }

INITRD="$(mdir -i "$mdir_target" :: 2>/dev/null | awk '/initramfs/ {print $1}' | head -n1)"
[ -n "$INITRD" ] || { echo "no initramfs found on boot partition"; mdir -i "$mdir_target" :: ; exit 1; }

DTB="bcm2711-rpi-4-b.dtb"
if ! mdir -i "$mdir_target" "::$DTB" >/dev/null 2>&1; then
  echo "expected $DTB not found on boot partition"
  mdir -i "$mdir_target" :: | grep -i '\.dtb' || true
  exit 1
fi

mcopy -i "$mdir_target" -o "::$KERNEL" "$OUT_DIR/Image"
mcopy -i "$mdir_target" -o "::$INITRD" "$OUT_DIR/initramfs-linux.img"
mcopy -i "$mdir_target" -o "::$DTB"    "$OUT_DIR/$DTB"

echo "extracted $KERNEL + $INITRD + $DTB to $OUT_DIR/"
