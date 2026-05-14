# ci/ — boot and install smoke tests

Scripts called by `.github/workflows/build.yaml` to verify a freshly-built
artifact actually boots before the mirror sync fires. See issue #982 for
the full design.

## What runs where

| Script                  | Used by                                 | What it does |
| ----------------------- | --------------------------------------- | ------------ |
| `boot-smoke.sh`         | `test-iso-boot`, `test-image-boot`      | Boots the artifact under QEMU, watches the serial console for a "system reached usable state" marker. |
| `extract-rpi-kernel.sh` | `test-image-boot` (aarch64 pre-step)    | Loop-mounts the rpi4 disk image, copies the kernel + initramfs out so QEMU's `-M virt` model can boot it. |
| `calamares-drive.sh`    | `test-iso-install` (Phase 2, advisory)  | Drives the Calamares wizard. Stub — see issue #982. |

## Running locally

```bash
# x86_64 ISO smoke test
./ci/boot-smoke.sh path/to/manjaro-sway.iso x86_64

# rpi4 image smoke test (needs aarch64 host for KVM; works under TCG otherwise)
./ci/extract-rpi-kernel.sh path/to/manjaro-sway-rpi4.img.xz
./ci/boot-smoke.sh path/to/manjaro-sway-rpi4.img aarch64
```

Both scripts exit non-zero on missing marker / unhealthy boot, which is what
the CI jobs key on.

## Adjusting the boot-pass criteria

The marker regex in `boot-smoke.sh` matches the first of:

- `Reached target Graphical Interface`
- `Reached target graphical-session`
- `Reached target Multi-User System`
- `manjaro login:`

If a future image stops emitting any of these on the serial console (e.g.
because the kernel cmdline drops `console=ttyS0`), the test will time out
even on a healthy boot. Fix by either restoring serial console in the
image or by switching the harness to a different probe (qemu monitor +
guest-agent, VNC + OCR, etc).
