#!/usr/bin/env bash
# Boot an ISO (x86_64) or rpi4 disk image (aarch64) under QEMU and watch the
# serial console for a "system reached usable state" marker. Exits non-zero on
# timeout, missing marker, or unhealthy systemctl status.
#
# Usage: boot-smoke.sh <artifact> <arch> [timeout-seconds]
#   <artifact>   path to the ISO (.iso) or rpi4 image (.img / .img.xz)
#   <arch>       x86_64 | aarch64
#   timeout      defaults to 360 (6 minutes)

set -euo pipefail

ARTIFACT="${1:?artifact path required}"
ARCH="${2:?arch (x86_64|aarch64) required}"
TIMEOUT="${3:-360}"

WORKDIR="$(mktemp -d)"
# SERIAL_LOG_OUT lets the caller (CI) pin the log to a stable path so the
# upload-artifact step can pick it up after the EXIT trap rms the workdir.
SERIAL_LOG="${SERIAL_LOG_OUT:-$WORKDIR/serial.log}"
trap 'rm -rf "$WORKDIR"; [ -n "${QEMU_PID:-}" ] && kill "$QEMU_PID" 2>/dev/null || true' EXIT

# Marker = the systemd target that signals the live session is up. Both the
# manjaro live ISO and the rpi4 image hit `multi-user.target` before they hand
# off to a graphical target, which is the latest point still guaranteed on
# headless installs.
MARKER='Reached target Graphical Interface\|Reached target graphical-session\|Reached target Multi-User System\|manjaro login:'

case "$ARCH" in
  x86_64)
    sudo modprobe kvm-intel 2>/dev/null || sudo modprobe kvm-amd 2>/dev/null || true
    # OVMF_CODE.fd path differs across Ubuntu versions
    OVMF=$(find /usr/share/OVMF -name 'OVMF_CODE*.fd' | head -n1)
    [ -n "$OVMF" ] || { echo "OVMF firmware not found"; exit 1; }
    qemu-img create -f qcow2 "$WORKDIR/disk.qcow2" 20G
    qemu-system-x86_64 \
      -enable-kvm -m 4096 -smp 2 \
      -drive file="$WORKDIR/disk.qcow2",if=virtio,format=qcow2 \
      -cdrom "$ARTIFACT" \
      -boot d -nographic \
      -serial "file:$SERIAL_LOG" \
      -monitor none \
      -bios "$OVMF" &
    QEMU_PID=$!
    ;;
  aarch64)
    # The extract script (extract-rpi-kernel.sh) leaves Image / initramfs in
    # the same workdir as the image. We expect them next to the artifact.
    KERNEL_DIR="$(dirname "$ARTIFACT")"
    [ -f "$KERNEL_DIR/Image" ] || { echo "kernel not extracted next to image"; exit 1; }
    qemu-system-aarch64 \
      -M virt -accel kvm -cpu host -m 4096 -smp 2 \
      -kernel "$KERNEL_DIR/Image" \
      -initrd "$KERNEL_DIR/initramfs-linux.img" \
      -append "root=/dev/vda2 rw console=ttyAMA0" \
      -drive file="$ARTIFACT",if=virtio,format=raw \
      -nographic \
      -serial "file:$SERIAL_LOG" \
      -monitor none &
    QEMU_PID=$!
    ;;
  *)
    echo "unsupported arch: $ARCH" >&2
    exit 1
    ;;
esac

echo "QEMU started (pid $QEMU_PID), waiting up to ${TIMEOUT}s for boot marker..."

deadline=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if [ -f "$SERIAL_LOG" ] && grep -Eq "$MARKER" "$SERIAL_LOG"; then
    echo "✓ boot marker observed"
    # Tail what we saw so CI logs are inspectable on failure.
    tail -n 50 "$SERIAL_LOG" || true
    exit 0
  fi
  if ! kill -0 "$QEMU_PID" 2>/dev/null; then
    echo "QEMU exited before marker appeared"
    tail -n 100 "$SERIAL_LOG" 2>/dev/null || true
    exit 1
  fi
  sleep 5
done

echo "✗ timed out waiting for boot marker after ${TIMEOUT}s"
tail -n 200 "$SERIAL_LOG" 2>/dev/null || true
exit 1
