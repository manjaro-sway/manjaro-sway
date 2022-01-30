# Manjaro Sway Edition
[![All Contributors](https://img.shields.io/badge/dynamic/json?color=important&label=contributors&query=%24.contributors.length&url=https%3A%2F%2Fraw.githubusercontent.com%2FManjaro-Sway%2Fmanjaro-sway%2Fmain%2F.all-contributorsrc)](#contributors-)
[![Matrix](https://img.shields.io/matrix/manjaro-sway:matrix.org)](https://matrix.to/#/#manjaro-sway:matrix.org)
[![repo_build](https://github.com/manjaro-sway/packages/workflows/repo-add/badge.svg?event=repository_dispatch)](https://github.com/manjaro-sway/packages/actions)
[![iso_build](https://github.com/manjaro-sway/manjaro-sway/workflows/iso_build/badge.svg?event=repository_dispatch)](https://github.com/manjaro-sway/manjaro-sway/actions)
[![downloads](https://img.shields.io/badge/dynamic/json?color=green&label=downloads&cache=3600&query=count&url=https%3A%2F%2Freleases-download-count.vercel.app%2Fapi%2Fmanjaro-sway%2Fmanjaro-sway%3Fsuffix%3Diso%2Czip)](https://github.com/Manjaro-Sway/manjaro-sway/releases/latest)
[![settings release (latest by date)](https://img.shields.io/github/v/release/manjaro-sway/desktop-settings)](https://github.com/Manjaro-Sway/desktop-settings/releases/latest)
[![lts](https://img.shields.io/badge/dynamic/json?label=lts&query=%24%5B%3A1%5D.packageName&url=https%3A%2F%2Fkernel-info.manjaro-sway.download%2F%3Fcategory%3Dlongterm)](https://github.com/Manjaro-Sway/manjaro-sway/releases/latest)
[![stable](https://img.shields.io/badge/dynamic/json?label=stable&query=%24%5B%3A1%5D.packageName&url=https%3A%2F%2Fkernel-info.manjaro-sway.download%2F%3Fcategory%3Dstable)](https://github.com/Manjaro-Sway/manjaro-sway/releases/latest)

[![watch it in action](https://img.youtube.com/vi/34DIO61GxAE/0.jpg)](https://www.youtube.com/watch?v=34DIO61GxAE "watch it in action")

We are building a manjaro sway edition - with the following principles:

- use a decent cli/tui solution
- convention overrideable by configuration
- prepare opt-out
- build everything automatically

## How to install

You can find the weekly ISO images on [github releases](https://github.com/manjaro-sway/manjaro-sway/releases).
To extract the regular images, download both the `z01` and the `zip` files, and run the command:

```bash
cat *.z* >tmp.zip && unzip tmp.zip
```

You can create a bootable USB stick using [Etcher](https://www.balena.io/etcher/). 
Check our [FAQ](SUPPORT.md) for additional hints.

## Known issues

- nvidia proprietary drivers <470 are not supported by sway.
- nvidia's 470 drivers and the 5.14 Kernel have just added sway support for proprietary drivers and are known to cause problems.
- nvidia open source drivers (noveau) are [known to cause problems](https://github.com/Manjaro-Sway/manjaro-sway/issues/140),
  refer to the [arch wiki for pointers](https://wiki.archlinux.org/title/Sway#Sway_v1.6_shows_garbage_or_blank_screen_when_using_nouveau)
- vmware player is [known to cause problems similar to nouveau](https://github.com/Manjaro-Sway/manjaro-sway/issues/139) -
  you could use gnome boxes or virtualbox instead - refer to the [arch wiki for pointers](https://wiki.archlinux.org/title/Sway#Virtualization) 

### Screenshots

![desktop](docs/_includes/desktop.png?raw=true)
![autotiling](docs/_includes/autotiling.png?raw=true)
![help menu](docs/_includes/help.png?raw=true)
![htop](docs/_includes/htop.png?raw=true)
![launcher](docs/_includes/launcher.png?raw=true)
![nmtui](docs/_includes/nmtui.png?raw=true)
![pamac](docs/_includes/pamac.png?raw=true)
![youtube](docs/_includes/youtube.png?raw=true)

### Credentials

```
user: manjaro
password: manjaro
```

## Development

### Sources

- [iso profile](https://github.com/manjaro-sway/iso-profiles/tree/sway/community/sway)
- [desktop settings](https://github.com/manjaro-sway/desktop-settings/tree/sway/community/sway)

### How to Build

1. Check out the ISO profile
2. Run this command in the root directory

```bash
buildiso -p sway
```

### Credits

- initial inspiration came from the [sway branch in the manjaro iso profiles repo](https://gitlab.manjaro.org/profiles-and-settings/iso-profiles/-/tree/sway)
- initially a lot of work got copied from the [manjaro sway arm overlay](https://gitlab.manjaro.org/manjaro-arm/applications/arm-profiles/-/tree/master/overlays/sway)
- the background image is [beautifully made by reddit user u/atlas-ark](https://www.reddit.com/r/wallpaper/comments/kmh680/1920x1080_all_resolutions_available_dark_light/?utm_source=share&utm_medium=web2x&context=3)
- the logo is a contribution by [André Vallestero](https://github.com/AndreVallestero)

### Donations

If you like our distribution and have some bucks to spare, please consider contributions to the projects and developers we rely on the most:

- for sway and wlroots, consider [Drew DeVault](https://drewdevault.com/donate)
- for waybar, consider [Alexis Rouillard](https://github.com/sponsors/Alexays)

### Contributors ✨

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
    <td align="center"><a href="https://github.com/FallenChromium"><img src="https://avatars.githubusercontent.com/u/43214067?v=4?s=100" width="100px;" alt=""/><br /><sub><b>FallenChromium</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=FallenChromium" title="Code">💻</a> <a href="#ideas-FallenChromium" title="Ideas, Planning, & Feedback">🤔</a></td>
    <td align="center"><a href="http://MuratovAS.github.io"><img src="https://avatars.githubusercontent.com/u/50487552?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Алексей Муратов </b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/issues?q=author%3AMuratovAS" title="Bug reports">🐛</a> <a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=MuratovAS" title="Code">💻</a></td>
    <td align="center"><a href="http://www.mscneuro.uni-freiburg.de/"><img src="https://avatars.githubusercontent.com/u/33870649?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Hakan Yilmaz</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/issues?q=author%3Ahakanyi" title="Bug reports">🐛</a> <a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=hakanyi" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/ahoneybun"><img src="https://avatars.githubusercontent.com/u/4884946?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Aaron Honeycutt</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=ahoneybun" title="Documentation">📖</a></td>
    <td align="center"><a href="https://github.com/vncsna"><img src="https://avatars.githubusercontent.com/u/4673693?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Vinicius Aguiar</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/issues?q=author%3Avncsna" title="Bug reports">🐛</a></td>
  </tr>
  <tr>
    <td align="center"><a href="https://github.com/Zeioth"><img src="https://avatars.githubusercontent.com/u/3357792?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Zeioth</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=Zeioth" title="Code">💻</a></td>
    <td align="center"><a href="https://github.com/xeruf"><img src="https://avatars.githubusercontent.com/u/13354331?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Janek</b></sub></a><br /><a href="#maintenance-xeruf" title="Maintenance">🚧</a></td>
    <td align="center"><a href="https://github.com/fraunos"><img src="https://avatars.githubusercontent.com/u/6673521?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Michał Wołoszyn</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=fraunos" title="Code">💻</a></td>
    <td align="center"><a href="http://annuel.nl"><img src="https://avatars.githubusercontent.com/u/4148154?v=4?s=100" width="100px;" alt=""/><br /><sub><b>annuel</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/commits?author=nnuel" title="Documentation">📖</a></td>
    <td align="center"><a href="https://github.com/aboettger"><img src="https://avatars.githubusercontent.com/u/206222?v=4?s=100" width="100px;" alt=""/><br /><sub><b>Andreas Böttger</b></sub></a><br /><a href="https://github.com/Manjaro-Sway/manjaro-sway/issues?q=author%3Aaboettger" title="Bug reports">🐛</a></td>
  </tr>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
