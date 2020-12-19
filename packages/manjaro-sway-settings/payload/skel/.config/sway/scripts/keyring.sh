#!/bin/sh
eval $(gnome-keyring-daemon --daemonize --start --components=gpg,pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
