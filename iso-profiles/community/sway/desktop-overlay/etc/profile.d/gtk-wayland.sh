#!/bin/sh

# Most pure GTK3 apps use wayland by default, but some,
# like Firefox, need the backend to be explicitely selected.
#export LD_PRELOAD=/usr/lib/libgtk3-nocsd.so.0
export LIBVA_DRIVER_NAME=v4l2_request
export LIBVA_V4L2_REQUEST_VIDEO_PATH=/dev/video1
export MOZ_ENABLE_WAYLAND=1
export MOZ_DBUS_REMOTE=1
export GTK_CSD=0
