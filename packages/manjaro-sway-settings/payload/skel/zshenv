if [ -n $DESKTOP_SESSION ]; then
  eval $(/usr/bin/gnome-keyring-daemon --daemonize --start --components=gpg,pkcs11,secrets,ssh)
  export GNOME_KEYRING_CONTROL GNOME_KEYRING_PID GPG_AGENT_INFO SSH_AUTH_SOCK
fi
