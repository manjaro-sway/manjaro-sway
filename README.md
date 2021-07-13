# manjaro sway edition
<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-9-orange.svg?style=flat-square)](#contributors-)
<!-- ALL-CONTRIBUTORS-BADGE:END -->
[![repo_build](https://github.com/manjaro-sway/packages/workflows/repo-add/badge.svg?event=repository_dispatch)](https://github.com/manjaro-sway/packages/actions)
[![iso_build](https://github.com/manjaro-sway/manjaro-sway/workflows/iso_build/badge.svg?event=repository_dispatch)](https://github.com/manjaro-sway/manjaro-sway/actions)
![downloads](https://img.shields.io/badge/dynamic/json?color=green&label=downloads&cache=3600&query=count&url=https%3A%2F%2Freleases-download-count.vercel.app%2Fapi%2Fmanjaro-sway%2Fmanjaro-sway%3Fsuffix%3Diso%2Czip)

## description

[![watch it in action](https://yt-embed.herokuapp.com/embed?v=34DIO61GxAE)](https://www.youtube.com/watch?v=34DIO61GxAE "watch it in action")

this is an approach to create a regular manjaro sway built - with to following paradigms:

- try to use a decent cli solution whenever available and commonly acceptable
- always use convention that can be overridden by configuration
- build everything in automation (iso images, packages)

## where can I download an iso?

images are build and uploaded in a relatively regular interval to [github releases](https://github.com/manjaro-sway/manjaro-sway/releases)

## how to upgrade?

after upgrading packages, you will sometimes need to update you skeleton:

```
cp -rf /etc/skel/.config/* ~/.config
```

keep in mind that this could cause problems with customizations you made. make a backup pls.

## what are the commands?

you can reach a quick introduction pressing `Super + Shift + ?`

## unknown public key

the public key used for our package repo is not yet inside the manjaro keyring. until we are, allow our key manually:

```
pacman-key --keyserver keys.openpgp.org --recv-key A44C644D792767CED7941AFEABB2075D5F310CF8
```

## unable to log in virtual machines

While it seems to work out of the box in some kvm/qemu environments (Gnome Boxes seems to work), you need to enable 3D acceleration in most of them. Refer [here](https://github.com/Manjaro-Sway/manjaro-sway/issues/56) for further information and feedback.

## what doesn't work yet?

- blurry fonts in xwayland

Otherwise: [you tell me](https://github.com/manjaro-sway/manjaro-sway/issues). I'd be happy to try to even out everything. PRs will be accepted in the repos listed below.

## sources

- [iso profile](https://github.com/manjaro-sway/iso-profiles/tree/sway/community/sway)
- [desktop settings](https://github.com/manjaro-sway/desktop-settings/tree/sway/community/sway)

## building

1. check out the iso profile
2. `buildiso -p sway`

## screenshots

![desktop](docs/_includes/desktop.png?raw=true)
![help menu](docs/_includes/help.png?raw=true)
![htop](docs/_includes/htop.png?raw=true)
![launcher](docs/_includes/launcher.png?raw=true)
![nmtui](docs/_includes/nmtui.png?raw=true)
![pamac](docs/_includes/pamac.png?raw=true)
![ranger](docs/_includes/ranger.png?raw=true)
![qutebrowser](docs/_includes/qutebrowser.png?raw=true)
![mako](docs/_includes/mako.png?raw=true)

## credentials

```
user: manjaro
password: manjaro
```

## first boot

1. make chromium use native window decorations

![chromium](public/_includes/chromium.png?raw=true)

2. enable [this flag] (chrome://flags/#enable-webrtc-pipewire-capturer)(`chrome://flags/#enable-webrtc-pipewire-capturer`) to allow screensharing in chromium

3. [set your own api key in mps-youtube](https://github.com/mps-youtube/mps-youtube/wiki/Troubleshooting#youtube-error-403-the-request-cannot-be-completed-because-you-have-exceeded-your-quota)

4. fasttrack mirrors: `sudo pacman-mirrors --geoip && sudo pacman -Syyu`

5. auto enable bluetooth on boot: `echo "AutoEnable=true" >> /etc/bluetooth/main.conf`

## credits

- initial inspiration came from the [sway branch in the manjaro iso profiles repo](https://gitlab.manjaro.org/profiles-and-settings/iso-profiles/-/tree/sway)
- most of the work is (with some modifications) copied from the [manjaro sway arm overlay](https://gitlab.manjaro.org/manjaro-arm/applications/arm-profiles/-/tree/master/overlays/sway)
- the background image is [beautifully made by reddit user u/atlas-ark](https://www.reddit.com/r/wallpaper/comments/kmh680/1920x1080_all_resolutions_available_dark_light/?utm_source=share&utm_medium=web2x&context=3)

## donations

if you like our distribution and have some bucks to spare, please consider contributions to the projects and developers we rely on the most:

- for sway and wlroots, consider [Drew DeVault](https://drewdevault.com/donate)
- for waybar, consider [Alexis Rouillard](https://github.com/sponsors/Alexays)
- for wofi, consider [Scoopta](https://liberapay.com/Scoopta)
- for kitty, consider [their project page](https://sw.kovidgoyal.net/kitty/support.html)

## Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="https://jonas-strassel.de/"><img src="https://avatars.githubusercontent.com/u/4662748?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Jonas Strassel</b></sub></a><br /><a href="#infra-boredland" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=boredland" title="Code">💻</a> <a href="#maintenance-boredland" title="Maintenance">🚧</a></td>
    <td align="center"><a href="https://github.com/simon-bueler"><img src="https://avatars.githubusercontent.com/u/5940667?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Simon Büeler</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=simon-bueler" title="Code">💻</a> <a href="#maintenance-simon-bueler" title="Maintenance">🚧</a> <a href="#ideas-simon-bueler" title="Ideas, Planning, & Feedback">🤔</a></td>
    <td align="center"><a href="https://github.com/AntonPicetti"><img src="https://avatars.githubusercontent.com/u/31367653?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Anton Picetti</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/issues?q=author%3AAntonPicetti" title="Bug reports">🐛</a> <a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=AntonPicetti" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/Mathew-D"><img src="https://avatars.githubusercontent.com/u/44036272?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Mathew</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/issues?q=author%3AMathew-D" title="Bug reports">🐛</a> <a href="#ideas-Mathew-D" title="Ideas, Planning, & Feedback">🤔</a> <a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=Mathew-D" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/bhartshorn"><img src="https://avatars.githubusercontent.com/u/56871?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Brandon Hartshorn</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/issues?q=author%3Abhartshorn" title="Bug reports">🐛</a></td>
    <td align="center"><a href="https://www.andrevallestero.com"><img src="https://avatars.githubusercontent.com/u/39736205?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Andre Vallestero</b></sub></a><br /><a href="#design-AndreVallestero" title="Design">🎨</a></td>
    <td align="center"><a href="http://falco.dev"><img src="https://avatars.githubusercontent.com/u/1385470?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Rafael dos Santos Silva</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=xfalcox" title="Code">💻</a></td>
  </tr>
  <tr>
    <td align="center"><a href="http://www.appelgriebsch.org"><img src="https://avatars.githubusercontent.com/u/6803419?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Andreas Gerlach</b></sub></a><br /><a href="#ideas-appelgriebsch" title="Ideas, Planning, & Feedback">🤔</a> <a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=appelgriebsch" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/Chrysostomus"><img src="https://avatars.githubusercontent.com/u/12002226?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Matti Hyttinen</b></sub></a><br /><a href="#ideas-Chrysostomus" title="Ideas, Planning, & Feedback">🤔</a></td>
  </tr>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!