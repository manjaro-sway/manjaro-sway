#!/usr/bin/env bash
# Make a stock Arch container able to build our packages.
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
pacman-key --populate archlinux

pacman -Syu --noconfirm --needed \
  base-devel git sudo python python-boto3 pacman-contrib

# Trust our own signing key before configuring the repository. A signed
# database whose key is unknown does not degrade to unsigned - pacman fails
# the whole sync with "invalid or corrupted database (PGP signature)", and
# every build after it cannot resolve so much as jq. SigLevel = Optional
# does not help: the check that fails happens before it applies.
if curl -fsSL "${REPO_URL}/manjaro-sway.gpg" -o /tmp/manjaro-sway.gpg &&
	gpg --show-keys /tmp/manjaro-sway.gpg >/dev/null 2>&1; then
	pacman-key --add /tmp/manjaro-sway.gpg
	gpg --show-keys --with-colons /tmp/manjaro-sway.gpg |
		awk -F: '/^fpr:/ {print $10}' |
		while read -r fingerprint; do pacman-key --lsign-key "$fingerprint"; done

	# Our own repository, so a package can depend on one published minutes
	# ago. DatabaseOptional, not DatabaseRequired: the very first run
	# publishes into an empty bucket, where no database exists at all.
	cat >>/etc/pacman.conf <<-EOF

		[manjaro-sway]
		SigLevel = Required DatabaseOptional
		Server = ${REPO_URL}/\$arch
	EOF
else
	echo "the manjaro-sway key is not published yet; building without the repository" >&2
fi

# a missing repository must not fail the sync: on the first ever run the
# bucket is empty and there is no database to fetch
pacman -Sy --noconfirm || true

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

useradd -m -G wheel builder 2>/dev/null || true
echo 'builder ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/builder
chmod 440 /etc/sudoers.d/builder
