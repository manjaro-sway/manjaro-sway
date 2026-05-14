#!/usr/bin/env bash
# Extract kernel + initramfs from a Manjaro ARM rpi4 disk image so QEMU's
# -M virt machine can boot it (the raspi4b machine model has too many gaps).
#
# Side effect: drops Image and initramfs-linux.img next to the input image,
# which is what boot-smoke.sh aarch64 expects.
#
# Usage: extract-rpi-kernel.sh <image>

set -euo pipefail

IMG="${1:?image path required}"
case "$IMG" in
  *.xz)  xz --decompress --keep --force "$IMG"; IMG="${IMG%.xz}";;
  *.zst) zstd -d --force "$IMG"; IMG="${IMG%.zst}";;
esac

OUT_DIR="$(dirname "$IMG")"
MNT="$(mktemp -d)"
trap 'sudo umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; sudo kpartx -d "$IMG" 2>/dev/null || true' EXIT

# Map partitions, find the boot (FAT32) partition.
sudo kpartx -av "$IMG"
LOOP_BASE="$(sudo kpartx -l "$IMG" | head -n1 | awk '{print $1}' | sed 's/p1$//')"
BOOT_DEV="/dev/mapper/${LOOP_BASE}p1"
[ -b "$BOOT_DEV" ] || { echo "boot partition not found at $BOOT_DEV"; exit 1; }

sudo mount -o ro "$BOOT_DEV" "$MNT"

# Manjaro rpi4 boot partition layout: Image (or kernel8.img) + an initramfs
# image. Names drift; pick the first match we can find.
for kn in Image kernel8.img kernel7l.img; do
  if [ -f "$MNT/$kn" ]; then
    sudo cp "$MNT/$kn" "$OUT_DIR/Image"
    break
  fi
done
[ -f "$OUT_DIR/Image" ] || { echo "no kernel image found on boot partition"; sudo ls -la "$MNT"; exit 1; }

INITRD="$(sudo find "$MNT" -maxdepth 1 -name 'initramfs-linux*.img' | head -n1)"
[ -n "$INITRD" ] || { echo "no initramfs found on boot partition"; sudo ls -la "$MNT"; exit 1; }
sudo cp "$INITRD" "$OUT_DIR/initramfs-linux.img"

sudo chown "$(id -u):$(id -g)" "$OUT_DIR/Image" "$OUT_DIR/initramfs-linux.img"
echo "extracted kernel + initramfs to $OUT_DIR/"
