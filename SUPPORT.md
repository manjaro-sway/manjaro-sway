# FAQ

## shortcuts

### how can I unzip the multi-part zip (.zip + .z01)?

if you archive manger doesn't support multipart zips already, you can just merge the two files using cat:

```bash
cat *.z* >tmp.zip
unzip tmp.zip
```

### how can I list the predefined shortcuts?

you can reach a quick introduction pressing `Super + Shift + ?`

### how can I (re-)declare shortcuts?

add your $bindsym lines to a file in `~/.config/sway/config.d/`:

```bash
$bindsym $mod+Shift+e exec $shutdown
```

to remove existing shortcuts (for example to reuse them elsewhere) you can `$unbindsym` them:

```bash
$unbindsym $mod+w
```

## upgrades

### how do I upgrade the ~/.config after an update?

after upgrading packages, you will sometimes need to update your skeleton:

```bash
cp -rf /etc/skel/.config/* ~/.config
```

keep in mind that this could cause problems with customizations you made. backup!

### why are pacman downloads so slow?

fasttrack mirrors: `sudo pacman-mirrors --geoip && sudo pacman -Syyu`

### how can I update the manjaro-sway-settings package (and all other packages from manjaro-sway)?

just prefix the repository: `pacman -S manjaro-sway/manjaro-sway-settings`

### why are your packages not in the regular manjaro repos?

we're working on it. submissions to them are partly manual and our signing key isn't yet officially part of the manjaro-keyring.

### how can I track updates?

major changes specific to this flavor of manjaro are mostly being done in the [desktop-settings repo](https://github.com/Manjaro-Sway/desktop-settings).

## customizing

### how can I customize sway without loosing my customizations after an upgrade?

you can add variable overrides in `~/.config/sway/definitions.d/` and add more sway configuration inside `~/.config/sway/config.d/`. please refer to the [arch wiki](https://wiki.archlinux.org/title/Sway) and the [sway wiki](https://github.com/swaywm/sway/wiki) for lots of ideas and hints. Make sure the files in either location end in .conf for them to be loaded.

### how can I customize waybar without loosing my customization after an upgrade?

copy over and edit the customization template, it will get picked up automatically:

```bash
cp ~/.config/waybar/config.jsonc.example ~/.config/waybar/config.jsonc
```

### how can I customize the foot terminal without loosing my customization after an upgrade?

copy over and edit the customization template, it will get picked up automatically:

```bash
cp ~/.config/foot/foot.ini.example ~/.config/foot/foot.ini
```

### how can I add my own and override existing sworkstyle icons?

just place them into a new file `~/.config/sworkstyle/config.toml` - it will extend and override the default configuration.

## setup and configuration

### how can I enable screen-share in chromium(-alike) browsers?

enable `chrome://flags/#enable-webrtc-pipewire-capturer`

### how can I log in inside a virtual machine?

While it seems to work out of the box in some kvm/qemu/libvirt environments (f.e. Gnome Boxes), you need to enable 3D acceleration in VirtualBox.

### how can I use the amazing mps-youtube?

[set your own api key in mps-youtube](https://github.com/mps-youtube/mps-youtube/wiki/Troubleshooting#youtube-error-403-the-request-cannot-be-completed-because-you-have-exceeded-your-quota)

### [how do I get an active bluetooth after login](https://wiki.archlinux.org/title/Bluetooth#Auto_power-on_after_boot)?

### how can I add more keyboard layouts to sway?

if you have a keyboard layout other then basic `us`, [add your keyboard settings](https://wiki.archlinux.org/title/Sway#Keymap) to a userspace configuration file (e.g. `~/.config/sway/config.d/01-keyboard.conf`).

### why doesn't it start with nvidia drivers?

[perhaps you're using the proprietary ones](https://github.com/swaywm/sway/issues/490).

### how do I disable the window focus flashing animation?

```bash
pacman -R flashfocus
```

### why do my keyboard settings from the installer have no effect?

Manjaro installer controls keyboard settings using xkb, sway doesn't support it. Please refer [here](https://wiki.archlinux.org/title/Sway#Keymap) for help.

### why do my auto-login settings from the installer have no effect?

greetd, our login messenger, is not supported by the manjaro installer. refer [here](https://wiki.archlinux.org/title/Greetd#Autologin) for help.

### how can I disable the night light feature?

```bash
pacman -R wlsunset
```

### how can I disable the dynamic workspace icons?

```bash
pacman -R sworkstyle
```

### how can I disable the window auto-tiling?

```bash
pacman -R autotiling
```
