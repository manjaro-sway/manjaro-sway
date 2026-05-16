#!/usr/bin/env bash
# Boot an ISO (x86_64) or rpi4 disk image (aarch64) under QEMU and watch the
# serial console for a "system reached usable state" marker. Exits non-zero on
# timeout, missing marker, or unhealthy systemctl status.
#
# Usage: boot-smoke.sh <artifact> <arch> [timeout-seconds]
#   <artifact>   path to the ISO (.iso) or rpi4 image (.img / .img.xz)
#   <arch>       x86_64 | aarch64
#   timeout      defaults to 360 (6 minutes)
#
# Environment:
#   BOOT_MARKER_REGEX     override the default boot marker
#   SERIAL_LOG_OUT        stable path for the serial log (CI artifact upload)
#   BOOT_VIRT_MACHINE=1   (aarch64) use -M virt + virtio-gpu instead of raspi4b
#   INJECT_HEADLESS_SWAY=1
#     After the live session's agetty login prompt appears on the serial
#     console, log in as root, stop greetd, pre-create XDG_RUNTIME_DIR (which
#     pam_systemd fails to set up under QEMU's constrained systemd environment),
#     and start sway with WLR_BACKENDS=headless so the compositor runs without
#     needing a real DRM device or logind seat.  Sway's autostart then execs
#     calamares.  Requires PTY serial (-serial pty) instead of file.

set -euo pipefail

ARTIFACT="${1:?artifact path required}"
ARCH="${2:?arch (x86_64|aarch64) required}"
TIMEOUT="${3:-360}"

WORKDIR="$(mktemp -d)"
SERIAL_LOG="${SERIAL_LOG_OUT:-$WORKDIR/serial.log}"

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
# wait for `calamares` (a journal entry emitted when the live session execs it).
MARKER="${BOOT_MARKER_REGEX:-audit.*hostname=manjaro|manjaro[-a-z]* *login:|op=PAM:session_open.*greetd}"

INJECT_HEADLESS_SWAY="${INJECT_HEADLESS_SWAY:-0}"

QEMU_PID=""
CAT_PID=""
SERIAL_PTY=""

cleanup() {
  [ -n "$CAT_PID" ] && kill "$CAT_PID" 2>/dev/null || true
  [ -n "$QEMU_PID" ] && kill "$QEMU_PID" 2>/dev/null || true
  rm -rf "$WORKDIR"
}
trap cleanup EXIT

# Interactive mode uses a PTY so we can write keystrokes back to the VM.
# QEMU announces the allocated PTY on stderr ("char device redirected to /dev/pts/N").
if [ "$INJECT_HEADLESS_SWAY" = "1" ]; then
  SERIAL_ARG="pty"
else
  SERIAL_ARG="file:$SERIAL_LOG"
fi

# Always capture QEMU stdout+stderr so we can grep PTY paths and dump errors.
# QEMU writes "char device redirected to /dev/pts/N" to stdout (not stderr).
QEMU_OUT="$WORKDIR/qemu.out"

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
    # virtio-gpu gives sway a DRM device so the Wayland compositor can start.
    # VNC display backend (no host window) makes the output appear "connected"
    # to the guest — without it, sway exits immediately finding no outputs.
    qemu-system-x86_64 \
      -enable-kvm -m 4096 -smp 2 \
      -drive file="$WORKDIR/disk.qcow2",if=virtio,format=qcow2 \
      -cdrom "$ARTIFACT" \
      -boot d \
      -display vnc=127.0.0.1:0 \
      -vga virtio \
      -serial "$SERIAL_ARG" \
      -monitor none \
      -bios "$OVMF" >"$QEMU_OUT" 2>&1 &
    QEMU_PID=$!
    ;;
  aarch64)
    # KVM only when host arch matches guest.
    if [ "$(uname -m)" = "aarch64" ] && [ -r /dev/kvm ]; then
      ACCEL_ARGS=(-accel kvm -cpu host)
    else
      ACCEL_ARGS=(-accel tcg -cpu cortex-a72)
    fi
    # QEMU's SD card emulation requires a power-of-two size — Manjaro's
    # 7.31 GiB image gets rejected ("Invalid SD card size"). Round up to
    # 8 GiB on a copy so we don't modify the cached artifact.
    SD_IMAGE="$WORKDIR/sd.img"
    cp --reflink=auto "$ARTIFACT" "$SD_IMAGE"
    qemu-img resize -f raw "$SD_IMAGE" 8G
    # qemu-img resize leaves the GPT backup header at the old end of the image.
    # The kernel rejects a GPT with a misplaced backup header and creates no
    # partition devices (vda1, vda2, …), so the root mount fails silently.
    sgdisk --move-second-header "$SD_IMAGE" >/dev/null

    if [ "${BOOT_VIRT_MACHINE:-0}" = "1" ]; then
      # The rpi4 kernel has no virtio-gpu, and -M raspi4b has no vc4 GPU, so
      # Sway/Wayland can't start headfully under either. Instead boot the rootfs
      # with the runner's generic kernel (standard Image format QEMU can load)
      # under -M virt. Userspace (greetd/sway/calamares) is kernel-agnostic.
      # Prefer -generic over -azure: the Azure PE/EFI stub format is not
      # loadable via QEMU's -kernel flag; the generic kernel is a plain Image.
      VMLINUZ=$(ls /boot/vmlinuz-*-generic 2>/dev/null | sort -V | tail -n1)
      INITRD=$(ls /boot/initrd.img-*-generic 2>/dev/null | sort -V | tail -n1)
      [ -n "$VMLINUZ" ] || { echo "no generic kernel found in /boot (install linux-image-generic)"; exit 1; }
      # Ubuntu aarch64 vmlinuz is an EFI PE stub; QEMU -kernel needs a raw
      # Image. extract-vmlinux finds the embedded compressed payload and
      # decompresses it.
      KERNEL="$WORKDIR/Image"
      curl -fsSL "https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux" \
        -o "$WORKDIR/extract-vmlinux"
      chmod +x "$WORKDIR/extract-vmlinux"
      # Ubuntu restricts /boot/vmlinuz-* to root (mode 600); make it readable.
      sudo chmod 644 "$VMLINUZ"
      "$WORKDIR/extract-vmlinux" "$VMLINUZ" > "$KERNEL"
      [ -s "$KERNEL" ] || { echo "extract-vmlinux produced empty output"; exit 1; }
      qemu-system-aarch64 \
        -M virt "${ACCEL_ARGS[@]}" -m 2048 -smp 4 \
        -kernel "$KERNEL" \
        -initrd "$INITRD" \
        -append "root=/dev/vda2 rw console=ttyAMA0 systemd.journald.forward_to_console=1 ignore_loglevel" \
        -drive file="$SD_IMAGE",if=virtio,format=raw \
        -device virtio-gpu \
        -display vnc=127.0.0.1:0 \
        -serial "$SERIAL_ARG" \
        -monitor none >"$QEMU_OUT" 2>&1 &
    else
      # Boot test: use the real rpi4 kernel under -M raspi4b for hardware fidelity.
      # The extract script leaves Image / initramfs / DTB next to the image.
      ART_DIR="$(dirname "$ARTIFACT")"
      [ -f "$ART_DIR/Image" ] || { echo "kernel not extracted next to image"; exit 1; }
      [ -f "$ART_DIR/bcm2711-rpi-4-b.dtb" ] || { echo "rpi4 DTB not extracted next to image"; exit 1; }
      # raspi4b caps DRAM at 2G; SD is the root device the rpi4 kernel expects.
      qemu-system-aarch64 \
        -M raspi4b "${ACCEL_ARGS[@]}" -m 2G -smp 4 \
        -kernel "$ART_DIR/Image" \
        -initrd "$ART_DIR/initramfs-linux.img" \
        -dtb "$ART_DIR/bcm2711-rpi-4-b.dtb" \
        -append "root=/dev/mmcblk1p2 rw rootwait earlycon=pl011,0xfe201000 console=ttyAMA0,115200 ignore_loglevel systemd.journald.forward_to_console=1" \
        -drive file="$SD_IMAGE",if=sd,format=raw \
        -nographic \
        -serial "file:$SERIAL_LOG" \
        -monitor none >"$QEMU_OUT" 2>&1 &
    fi
    QEMU_PID=$!
    ;;
  *)
    echo "unsupported arch: $ARCH" >&2
    exit 1
    ;;
esac

# PTY setup: find the device QEMU allocated, set it to raw mode, and forward
# its output to the serial log so the polling loop can grep the same file.
if [ "$INJECT_HEADLESS_SWAY" = "1" ]; then
  echo "Waiting for QEMU PTY allocation..."
  for i in $(seq 1 30); do
    sleep 1
    SERIAL_PTY=$(grep -m1 -oE '/dev/pts/[0-9]+' "$QEMU_OUT" 2>/dev/null || true)
    [ -n "$SERIAL_PTY" ] && break
  done
  if [ -z "$SERIAL_PTY" ]; then
    echo "PTY not found in QEMU output after 30s"
    cat "$QEMU_OUT" >&2
    exit 1
  fi
  echo "Serial PTY: $SERIAL_PTY"
  stty -F "$SERIAL_PTY" raw -echo 2>/dev/null || true
  # Forward PTY output to the log file in the background so the poll loop can
  # grep it.  cat keeps reading until QEMU closes the PTY on exit.
  cat "$SERIAL_PTY" >> "$SERIAL_LOG" &
  CAT_PID=$!
fi

echo "QEMU started (pid $QEMU_PID), waiting up to ${TIMEOUT}s for boot marker..."

deadline=$(( $(date +%s) + TIMEOUT ))
HEADLESS_INJECTED=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  if [ -f "$SERIAL_LOG" ] && grep -Eq "$MARKER" "$SERIAL_LOG"; then
    echo "✓ boot marker observed"
    # Tail what we saw so CI logs are inspectable on failure.
    tail -n 50 "$SERIAL_LOG" || true
    exit 0
  fi

  # When INJECT_HEADLESS_SWAY is active, intercept the agetty login prompt and
  # start sway with WLR_BACKENDS=headless to work around the pam_systemd
  # XDG_RUNTIME_DIR failure that occurs under QEMU's constrained environment.
  if [ "$INJECT_HEADLESS_SWAY" = "1" ] && [ "$HEADLESS_INJECTED" = "0" ] && \
     [ -f "$SERIAL_LOG" ] && grep -qE 'manjaro[-a-z]* *login:' "$SERIAL_LOG" 2>/dev/null; then
    echo "→ login prompt detected, injecting headless sway..."
    # Log in as root (no password on live ISO).
    printf 'root\n' > "$SERIAL_PTY"
    sleep 3
    # Stop greetd to prevent it from racing our sway for the Wayland socket,
    # then create the runtime dir pam_systemd would normally set up.
    printf 'systemctl stop greetd || true\n' > "$SERIAL_PTY"
    sleep 1
    printf 'mkdir -p /run/user/1000 && chown 1000:1000 /run/user/1000 && chmod 700 /run/user/1000\n' > "$SERIAL_PTY"
    sleep 1
    # Run sway as the live-session user with the headless backend (no DRM or
    # seat required).  nohup keeps sway alive after su exits.  Sway's autostart
    # execs calamares, which is what the install test is waiting for.
    printf 'su - manjaro -c "XDG_RUNTIME_DIR=/run/user/1000 WLR_BACKENDS=headless WLR_RENDERER=pixman nohup sway &>/tmp/sway.log &"\n' > "$SERIAL_PTY"
    HEADLESS_INJECTED=1
    echo "→ headless sway launched, waiting for calamares..."
  fi

  if ! kill -0 "$QEMU_PID" 2>/dev/null; then
    echo "QEMU exited before marker appeared"
    cat "$QEMU_OUT" 2>/dev/null || true
    tail -n 100 "$SERIAL_LOG" 2>/dev/null || true
    exit 1
  fi
  sleep 5
done

echo "✗ timed out waiting for boot marker after ${TIMEOUT}s"
tail -n 200 "$SERIAL_LOG" 2>/dev/null || true
exit 1
