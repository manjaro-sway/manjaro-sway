# FAQ

## how can I list the predefined shortcuts?

you can reach a quick introduction pressing `Super + Shift + ?`

## how do I upgrade the ~/.config after an update?

after upgrading packages, you will sometimes need to update you skeleton:

```
cp -rf /etc/skel/.config/* ~/.config
```

keep in mind that this could cause problems with customizations you made. backup!

## why does pacman complain about an unknown public key for manjaro-sway?

the public key used to sign our package repo is not yet inside the manjaro keyring. until we are, allow our key manually:

```
pacman-key --keyserver keys.openpgp.org --recv-key A44C644D792767CED7941AFEABB2075D5F310CF8
```

## how can I customize sway without loosing my customizations after an upgrade?

you can easily add more sway configuration inside `~/.config/sway/config.d/`. please refer to the [arch wiki](https://wiki.archlinux.org/title/Sway#Keymap) and the [sway wiki](https://github.com/swaywm/sway/wiki) for lots of ideas and hints.

## how can I log in inside a virtual machine?

While it seems to work out of the box in some kvm/qemu environments (Gnome Boxes seems to work), you need to enable 3D acceleration in most of them. Refer [here](https://github.com/Manjaro-Sway/manjaro-sway/issues/56) for further information and feedback.

## how do I make chromium use native window decorations (mostly: none)?

![chromium](docs/_includes/chromium.png?raw=true)

## how can I enable screen-share in chromium(-alike) browsers?

enable [this flag] (chrome://flags/#enable-webrtc-pipewire-capturer)(`chrome://flags/#enable-webrtc-pipewire-capturer`)

## how can I use the amazing mps-youtube?

[set your own api key in mps-youtube](https://github.com/mps-youtube/mps-youtube/wiki/Troubleshooting#youtube-error-403-the-request-cannot-be-completed-because-you-have-exceeded-your-quota)

## why are pacman downloads so slow?

fasttrack mirrors: `sudo pacman-mirrors --geoip && sudo pacman -Syyu`

## how do I get an active bluetooth after login?

auto enable bluetooth on boot: `echo "AutoEnable=true" >> /etc/bluetooth/main.conf`

## how can I add more keyboard layouts to sway?

if you have a keyboard layout other then basic `us`, [add your keyboard settings](https://wiki.archlinux.org/title/Sway#Keymap) to a userspace configuration file (e.g. `~/.config/sway/config.d/01-keyboard.conf`).

## how can I update the manjaro-sway-settings package (and all other packages from manjaro-sway)?

just prefix the repository: `pacman -S manjaro-sway/manjaro-sway-settings`

## why are your packages not in the regular manjaro repos?

we're working on it. submissions to them are partly manual and our signing key isn't yet officially part of the manjaro-keyring.

## how can I (re-)declare shortcuts?

add your $bindsym lines to a file in `~/.config/sway/config.d/`:

```
$bindsym $mod+Shift+e exec $shutdown
```

to remove existing shortcuts (for example to reuse them elsewhere) you can `$unbindsym` them:

```
$unbindsym $mod+w
```