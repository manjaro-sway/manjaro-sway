# ci/ — boot and install smoke tests

Scripts called by `.github/workflows/build.yaml` to verify freshly-built
artifacts actually boot and launch the installer before the mirror sync fires.

## What runs where

| CI job | Script(s) | Arch | What it checks |
|---|---|---|---|
| `test-iso-boot` | `boot-smoke.sh` | x86_64 | ISO boots to login prompt / greetd session |
| `test-image-boot` | `extract-rpi-kernel.sh` → `boot-smoke.sh` | aarch64 | rpi4 image boots to login prompt under `-M raspi4b` |
| `test-iso-install` | `boot-smoke.sh` | x86_64 | Calamares execs from the live ISO autostart |
| `test-image-install` | `boot-smoke.sh` | aarch64 | Calamares execs from the rpi4 OEM-setup autostart |

All four jobs are **gating**: `trigger-mirror` only fires when all pass.

### boot-smoke.sh

Boots an ISO or disk image under QEMU and tails the serial console for a
configurable marker regex. Default marker matches the first of:

- `audit.*hostname=manjaro` — kernel audit fires after `/etc/hostname` is
  processed; most reliable signal because it keeps flowing through `kauditd`
  after journald is up
- `manjaro[-a-z]* *login:` — agetty login prompt fallback
- `op=PAM:session_open.*greetd` — greetd handed off to a user session

Install tests override the marker with `BOOT_MARKER_REGEX='calamares'` and
set `INJECT_HEADLESS_SWAY=1` to start sway via the serial console after the
login prompt appears (see [INJECT_HEADLESS_SWAY](#inject_headless_sway) below).

### extract-rpi-kernel.sh

Reads the FAT32 boot partition with `mtools`, copies the kernel (`Image`),
initramfs, and Pi4 DTB out next to the image file. Used by `test-image-boot`
because QEMU's `-M raspi4b` needs them as separate files. Requires no `sudo`
and no loop devices.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `BOOT_MARKER_REGEX` | see above | ERE matched against the serial log to declare success |
| `SERIAL_LOG_OUT` | temp file | Stable path for the serial log; used for CI artifact upload |
| `BOOT_VIRT_MACHINE=1` | — | (aarch64) Boot under `-M virt` with the runner's generic kernel and `virtio-gpu` instead of `-M raspi4b`. Required for the install test because the rpi4 kernel has no virtio drivers. |
| `INJECT_HEADLESS_SWAY=1` | — | After the agetty login prompt appears, log in as root, stop greetd, pre-create `XDG_RUNTIME_DIR`, and start sway with `WLR_BACKENDS=headless WLR_RENDERER=pixman`. Sway's autostart then execs calamares. Needs PTY serial. |
| `SCREENSHOT_DIR` | — | Directory for stage screenshots captured via the QEMU monitor `screendump` command. Saved as PNG (ffmpeg/convert) or PPM fallback. Skipped on the raspi4b path which uses `-nographic`. |

### INJECT_HEADLESS_SWAY

`pam_systemd` fails to create `/run/user/1000` in QEMU's constrained
environment, causing sway to exit immediately. The workaround:

1. Detect `login:` prompt on the serial PTY
2. `root` login (no password on the live session)
3. `systemctl stop greetd` — prevents it from racing sway for the Wayland socket
4. `mkdir -p /run/user/1000 && chown 1000:1000 … && chmod 700 …`
5. `su - manjaro -c "XDG_RUNTIME_DIR=… WLR_BACKENDS=headless WLR_RENDERER=pixman nohup sway …"`

## Running locally

```bash
# x86_64 ISO boot smoke test
SERIAL_LOG_OUT=/tmp/serial.log ./ci/boot-smoke.sh path/to/manjaro-sway.iso x86_64

# x86_64 ISO install test (waits for calamares to exec, 12 min timeout)
INJECT_HEADLESS_SWAY=1 BOOT_MARKER_REGEX='calamares' SERIAL_LOG_OUT=/tmp/serial.log \
  ./ci/boot-smoke.sh path/to/manjaro-sway.iso x86_64 720

# rpi4 image boot smoke test (KVM on aarch64 host; TCG otherwise)
./ci/extract-rpi-kernel.sh path/to/manjaro-sway-rpi4.img.xz
SERIAL_LOG_OUT=/tmp/serial.log ./ci/boot-smoke.sh path/to/manjaro-sway-rpi4.img aarch64

# rpi4 image install test (uses runner kernel under -M virt, 12 min timeout)
BOOT_VIRT_MACHINE=1 INJECT_HEADLESS_SWAY=1 BOOT_MARKER_REGEX='calamares' \
  SERIAL_LOG_OUT=/tmp/serial.log ./ci/boot-smoke.sh path/to/manjaro-sway-rpi4.img.xz aarch64 720
```

Both scripts exit non-zero on missing marker, timeout, or early QEMU exit.

## Screenshots

When `SCREENSHOT_DIR` is set, `boot-smoke.sh` captures framebuffer screenshots
at each significant stage:

| Label | When |
|---|---|
| `login-prompt` | agetty `login:` detected (INJECT_HEADLESS_SWAY path) |
| `sway-injected` | headless sway command sent to serial |
| `t<N>s` | every ~60 s during the poll loop |
| `success` | boot marker matched |
| `timeout` / `qemu-exit` | failure paths |

Screenshots are uploaded as CI artifacts (`screenshots-iso-boot-*`,
`screenshots-iso-install-*`, `screenshots-image-install-*`) and are retained
even on failure (`if: always()`). The raspi4b boot test has no display and
produces no screenshots.
