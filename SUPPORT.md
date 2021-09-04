# FAQ

## Shortcuts

### How can I unzip the multi-part zip (.zip + .z01)?

If your archive manger doesn't support multipart zips already, you can just merge the two files using cat:

```bash
cat *.z* >tmp.zip
unzip tmp.zip
```

### How can I list the predefined shortcuts?

You can reach a quick introduction pressing `Super + Shift + ?`

### How can I (re-)declare shortcuts?

You can add your $bindsym lines to a file in `~/.config/sway/config.d/`:

```bash
$bindsym $mod+Shift+e exec $shutdown
```

to remove existing shortcuts (for example to reuse them elsewhere) you can `$unbindsym` them:

```bash
$unbindsym $mod+w
```

## Upgrades

### how do I upgrade the ~/.config after an update?

After upgrading packages, you will sometimes need to update your skeleton:

```bash
cp -rf /etc/skel/.config/* ~/.config
```

keep in mind that this could cause problems with customizations you made. backup!

### Why are pacman downloads so slow?

You can add fasttrack mirrors using this command:

```bash
sudo pacman-mirrors --geoip && sudo pacman -Syyu
```

### How can I update the manjaro-sway-settings package (and all other packages from manjaro-sway)?

Just prefix the repository using this command: 

```bash
pacman -S manjaro-sway/manjaro-sway-settings
```

### Why are your packages not in the regular manjaro repos?

We're working on getting them added to the main Manjaro repo. Submissions to them are partly manual and our signing key isn't yet officially part of the manjaro-keyring.

### How can I track updates?

Major changes specific to this flavor of manjaro are mostly being done in the [desktop-settings repo](https://github.com/Manjaro-Sway/desktop-settings).

## Customizing

### How can I customize sway without losing my customizations after an upgrade?

You can add variable overrides in `~/.config/sway/definitions.d/` and add more sway configuration inside `~/.config/sway/config.d/`. please refer to the [arch wiki](https://wiki.archlinux.org/title/Sway) and the [sway wiki](https://github.com/swaywm/sway/wiki) for lots of ideas and hints. Make sure the files in either location end in .conf for them to be loaded.

### How can I customize waybar without losing my customization after an upgrade?

Copy over and edit the customization template, it will get picked up automatically:

```bash
cp ~/.config/waybar/config.jsonc.example ~/.config/waybar/config.jsonc
```

### How can I customize the foot terminal without losing my customization after an upgrade?

Copy over and edit the customization template, it will get picked up automatically:

```bash
cp ~/.config/foot/foot.ini.example ~/.config/foot/foot.ini
```

### How can I add my own and override existing sworkstyle icons?

Copy over and edit the customization template, it will get picked up automatically:

```bash
cp ~/.config/sworkstyle/config.toml.example ~/.config/sworkstyle/config.toml
```

## Setup and configuration

### How can I move the waybar from top to bottom?

Change the waybar position by creating or updating your `~/.config/waybar/config.jsonc`:

```jsonc
{
    "include": [
        "/usr/share/sway/templates/waybar/config.jsonc"
    ],
    "position": "bottom"
}
```

### How can I enable screen-share in chromium(-alike) browsers?

Enable `chrome://flags/#enable-webrtc-pipewire-capturer`

### How can I log in inside a virtual machine?

While it seems to work out of the box in some kvm/qemu/libvirt environments (f.e. Gnome Boxes), you need to enable 3D acceleration in VirtualBox.

### How can I use the amazing mps-youtube?

[set your own api key in mps-youtube](https://github.com/mps-youtube/mps-youtube/wiki/Troubleshooting#youtube-error-403-the-request-cannot-be-completed-because-you-have-exceeded-your-quota)

### How do I get an active bluetooth after login?

Refer to this [link](https://wiki.archlinux.org/title/Bluetooth#Auto_power-on_after_boot)

### How can I add more keyboard layouts to sway?

Copy over our configuration example:

```bash
cp ~/.config/sway/config.d/XX-keyboard.conf.example ~/.config/sway/config.d/01-keyboard.conf
```

refer to `man sway-input` and the [arch wiki](https://wiki.archlinux.org/title/Sway#Keymap) for more pointers.

### Why doesn't it start with nvidia drivers?

[perhaps you're using the proprietary ones](https://github.com/swaywm/sway/issues/490).

### How do I disable the window focus flashing animation?

```bash
pacman -R flashfocus
```

### Why do my keyboard settings from the installer have no effect?

Manjaro installer controls keyboard settings using xkb, sway doesn't support it. Please refer [here](https://wiki.archlinux.org/title/Sway#Keymap) for help.

### Why do my auto-login settings from the installer have no effect?

greetd, our login messenger, is not supported by the manjaro installer. refer [here](https://wiki.archlinux.org/title/Greetd#Autologin) for help.

### How can I disable the night light feature?

```bash
pacman -R wlsunset
```

### How can I disable the dynamic workspace icons?

```bash
pacman -R sworkstyle
```

### How can I disable the window auto-tiling?

```bash
pacman -R autotiling
```

### How can I enable github notifications?

install and authenticate with the github cli:

```bash
pacman -S github-cli
gh auth login
```
