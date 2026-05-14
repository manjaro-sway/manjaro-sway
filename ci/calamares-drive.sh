#!/usr/bin/env bash
# Drive a Calamares install end-to-end against a booted live ISO VM.
#
# Skeleton — Phase 2 of the boot-test plan. The Calamares Qt GUI has no
# unattended mode, so this script is the documented click sequence: it relies
# on either SSH-into-live-VM + xdotool or serial-attached expect, whichever
# the live session supports.
#
# Run after boot-smoke.sh has confirmed the live ISO is up. Expects the VM to
# still be running with SSH forwarded on host port 2222 (per boot-smoke's
# launch args).
#
# Status: NOT YET IMPLEMENTED. Exits 1 so the calling job sees explicit
# failure when continue-on-error is eventually flipped to false.

set -euo pipefail

ISO="${1:?iso path required}"
DISK="${2:?target disk image (qcow2) required}"

echo "calamares-drive.sh: stub — see issue #982 Phase 2 for the implementation outline" >&2
echo "  ISO:   $ISO"
echo "  DISK:  $DISK"
exit 1
