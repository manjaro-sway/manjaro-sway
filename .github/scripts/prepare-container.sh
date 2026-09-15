#!/usr/bin/env bash
# Make a stock Manjaro container able to build our packages.
#
# Manjaro, not Arch: this is an overlay on Manjaro's repositories, and
# several packages depend on names only Manjaro has - manjaro-base-skel,
# matcha-gtk-theme, papirus-maia-icon-theme, kvantum-theme-matcha. On Arch
# those cannot be resolved at all, which failed manjaro-sway-settings with
# "Could not resolve all dependencies". Building against the distribution
# the packages are installed on is also what keeps a compiled package
# linked against the libraries its users actually have.
#
# Two things it cannot do out of the box: makepkg refuses to run as root, and
# our own packages depend on each other - manjaro-sway-settings needs
# sway-services and grimshot - so the repository being published has to be
# readable while it is being built.
set -euo pipefail

REPO_URL="${REPO_URL:-https://sway.manjaro.download/packages/unstable}"

# pacman 7 drops privileges to the 'alpm' user and confines downloads with
# Landlock. A container whose seccomp profile blocks the landlock syscalls
# fails the whole sync with "the Landlock ruleset could not be applied" -
# seen on the ARM runners. The isolation is worth having where the kernel
# allows it, so probe rather than switch it off unconditionally.
if ! pacman -Sy --noconfirm >/dev/null 2>&1; then
	echo "pacman's download sandbox is unavailable here; disabling it" >&2
	# into [options], not appended: a directive after the last repository
	# section belongs to THAT section, where pacman ignores it with
	# "directive 'DisableSandbox' in section 'aur' not recognized" - which
	# is what an image with a trailing [aur] section made happen.
	sed -i '0,/^\[options\]/s//[options]\nDisableSandbox/' /etc/pacman.conf
fi

pacman-key --init
pacman-key --populate archlinux manjaro

# The branch the repository targets. The image ships stable mirrors, and a
# package built against stable but published for unstable users links
# against older libraries than they have.
pacman-mirrors --api --set-branch unstable >/dev/null
pacman-mirrors --geoip >/dev/null 2>&1 || pacman-mirrors -f5 >/dev/null

# Retried, and -Syy on the retry: a mirror's database is published ahead of
# the package files it names, so a sync that lands in that window fails with
# a 404 for a file the database promises. Refreshing the database picks a
# mirror that has both. Transient, but it takes the whole build with it.
install_packages() {
  pacman -Syu --noconfirm --needed \
    base-devel git sudo python python-boto3 pacman-contrib
}
for attempt in 1 2 3; do
  if install_packages; then
    break
  fi
  if [ "$attempt" = 3 ]; then
    echo "## could not install the build dependencies after $attempt attempts" >&2
    exit 1
  fi
  echo "## install failed (attempt $attempt); refreshing mirrors and retrying" >&2
  pacman-mirrors -f5 >/dev/null 2>&1 || true
  pacman -Syy --noconfirm >/dev/null 2>&1 || true
  sleep 15
done

# Trust our own signing key before configuring the repository. A signed
# database whose key is unknown does not degrade to unsigned - pacman fails
# the whole sync with "invalid or corrupted database (PGP signature)", and
# every build after it cannot resolve so much as jq. SigLevel = Optional
# does not help: the check that fails happens before it applies.
#
# Both the key AND the database, because a configured repository whose
# database 404s fails every later `pacman -Syu` outright - not just the
# sync here, which tolerates it. DatabaseOptional does not cover a 404:
# it makes an *unsigned* database acceptable, not an absent one. The key
# is published before the first build, so "key exists" does not imply
# "database exists" and the two have to be probed separately.
if curl -fsSL "${REPO_URL}/manjaro-sway.gpg" -o /tmp/manjaro-sway.gpg &&
	gpg --show-keys /tmp/manjaro-sway.gpg >/dev/null 2>&1 &&
	curl -fsIL -o /dev/null "${REPO_URL}/$(uname -m)/manjaro-sway.db"; then
	pacman-key --add /tmp/manjaro-sway.gpg
	gpg --show-keys --with-colons /tmp/manjaro-sway.gpg |
		awk -F: '/^fpr:/ {print $10}' |
		while read -r fingerprint; do pacman-key --lsign-key "$fingerprint"; done

	# Our own repository, so a package can depend on one published minutes
	# ago.
	cat >>/etc/pacman.conf <<-EOF

		[manjaro-sway]
		SigLevel = Required
		Server = ${REPO_URL}/\$arch
	EOF
else
	echo "the manjaro-sway repository is not published yet; building without it" >&2
fi

pacman -Sy --noconfirm

# Stock OPTIONS carry `debug`, which makes a <name>-debug package beside
# every compiled one - detached symbols and /usr/src/debug sources. Those
# would enter the repository as first-class packages nobody asked for, and
# roughly double what a build leg uploads. OPTIONS is readonly inside
# makepkg and has no flag, so the config file is the only place to say it.
#
# Negate every bare `debug` and leave an existing `!debug` alone. The
# previous expression matched `debug` inside `!debug` too, so a config
# that already carried the negation became `!!debug` - which makepkg
# rejects outright with "OPTIONS array contains unknown option", failing
# the build before it starts. Requiring a space or paren on both sides is
# what distinguishes a bare `debug` from one already negated - and keeps
# it off `debuginfo`-style names that merely start the same way.
sed -i -E 's/([ (])debug([ )])/\1!debug\2/g' /etc/makepkg.conf

# The manjaro image already has a builder user, so useradd no-ops there
# and -m creates nothing: make sure the home it points at exists and
# belongs to them either way, or makepkg cannot write a gnupg home.
useradd -m -G wheel builder 2>/dev/null || usermod -aG wheel builder
builder_home=$(getent passwd builder | cut -d: -f6)
install -d -o builder -g builder -m 755 "$builder_home"
echo 'builder ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder
