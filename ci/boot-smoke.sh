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

# Default markers signalling "userspace booted far enough":
#  - audit hostname=manjaro* — kernel audit fires this only after /etc/hostname
#    is processed by userspace systemd. Most reliable signal we have because
#    systemd[1] stops writing to the kernel ring buffer once journald is up
#    (around t=30s), so its later `Reached target` lines never reach the
#    serial. Audit keeps flowing through kauditd.
#  - manjaro login: — classic getty prompt fallback for live ISOs that don't
#    flip to greetd immediately.
#  - greetd PAM session_open — display manager handed off to a user session.
#
# Caller can override via BOOT_MARKER_REGEX, used e.g. by the install test to
# wait for `exe="/usr/bin/calamares"` (an audit SYSCALL line emitted when the
# live session auto-execs calamares).
MARKER="${BOOT_MARKER_REGEX:-audit.*hostname=manjaro|manjaro[-a-z]* *login:|op=PAM:session_open.*greetd}"

case "$ARCH" in
  x86_64)
    sudo modprobe kvm-intel 2>/dev/null || sudo modprobe kvm-amd 2>/dev/null || true
    # Prefer the unified OVMF firmware (Ubuntu: /usr/share/OVMF/OVMF.fd,
    # Manjaro: /usr/share/edk2/x64/OVMF.4m.fd). The split CODE/VARS *_4M.fd
    # files require -drive if=pflash and a writable VARS copy, which we don't
    # need for a one-shot boot test.
    OVMF=$(find /usr/share -maxdepth 4 \( -name 'OVMF.fd' -o -name 'OVMF.4m.fd' -o -name 'OVMF_CODE.fd' \) 2>/dev/null | grep -v secboot | head -n1)
    [ -n "$OVMF" ] || { echo "OVMF firmware not found under /usr/share"; find /usr/share -name 'OVMF*' 2>/dev/null | head; exit 1; }
    qemu-img create -f qcow2 "$WORKDIR/disk.qcow2" 20G
    # virtio-gpu gives sway a DRM device. Without it, the wayland compositor
    # can't find any output and exits immediately (greetd session opens then
    # closes within ms). -display none keeps QEMU headless host-side.
    qemu-system-x86_64 \
      -enable-kvm -m 4096 -smp 2 \
      -drive file="$WORKDIR/disk.qcow2",if=virtio,format=qcow2 \
      -cdrom "$ARTIFACT" \
      -boot d \
      -display none \
      -vga virtio \
      -serial "file:$SERIAL_LOG" \
      -monitor none \
      -bios "$OVMF" &
    QEMU_PID=$!
    ;;
  aarch64)
    # The extract script leaves Image / initramfs / DTB in the same workdir
    # as the image. Booting via -M raspi4b (not -M virt) because the Manjaro
    # rpi4 kernel has no virtio drivers compiled in — it's built strictly
    # for Pi hardware and only knows SD/MMC + USB.
    ART_DIR="$(dirname "$ARTIFACT")"
    [ -f "$ART_DIR/Image" ] || { echo "kernel not extracted next to image"; exit 1; }
    [ -f "$ART_DIR/bcm2711-rpi-4-b.dtb" ] || { echo "rpi4 DTB not extracted next to image"; exit 1; }
    # QEMU's SD card emulation requires a power-of-two size — Manjaro's
    # 7.31 GiB image gets rejected ("Invalid SD card size"). Round up to
    # 8 GiB on a copy so we don't modify the cached artifact.
    SD_IMAGE="$WORKDIR/sd.img"
    cp --reflink=auto "$ARTIFACT" "$SD_IMAGE"
    qemu-img resize -f raw "$SD_IMAGE" 8G
    # KVM only when host arch matches guest. CI's ubuntu-24.04-arm runner is
    # aarch64-native; local x86 dev hosts fall back to TCG (slow but works).
    if [ "$(uname -m)" = "aarch64" ] && [ -r /dev/kvm ]; then
      ACCEL_ARGS=(-accel kvm)
    else
      ACCEL_ARGS=(-accel tcg)
    fi
    # raspi4b caps DRAM at 2G in QEMU; SD is the root device the rpi4 kernel
    # expects, so use if=sd. Console on PL011 UART matches the rpi config.txt.
    qemu-system-aarch64 \
      -M raspi4b "${ACCEL_ARGS[@]}" -m 2G -smp 4 \
      -kernel "$ART_DIR/Image" \
      -initrd "$ART_DIR/initramfs-linux.img" \
      -dtb "$ART_DIR/bcm2711-rpi-4-b.dtb" \
      -append "root=/dev/mmcblk1p2 rw rootwait earlycon=pl011,0xfe201000 console=ttyAMA0,115200 ignore_loglevel" \
      -drive file="$SD_IMAGE",if=sd,format=raw \
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
