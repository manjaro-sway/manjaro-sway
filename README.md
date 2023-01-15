# Manjaro Sway Edition

[![All Contributors](https://img.shields.io/badge/dynamic/json?color=important&label=contributors&query=%24.contributors.length&url=https%3A%2F%2Fraw.githubusercontent.com%2FManjaro-Sway%2Fmanjaro-sway%2Fmain%2F.all-contributorsrc)](#contributors-)
[![Matrix](https://img.shields.io/matrix/manjaro-sway:matrix.org)](https://matrix.to/#/#manjaro-sway:matrix.org)
[![repo build](https://github.com/manjaro-sway/packages/workflows/repo-add/badge.svg?event=repository_dispatch)](https://github.com/manjaro-sway/packages/actions)
[![iso build](https://github.com/Manjaro-Sway/manjaro-sway/actions/workflows/iso_build.yaml/badge.svg)](https://github.com/Manjaro-Sway/manjaro-sway/actions/workflows/iso_build.yaml)
[![downloads](https://img.shields.io/badge/dynamic/json?color=green&label=downloads&cache=3600&query=count&url=https%3A%2F%2Fmanjaro-sway.download/count)](https://manjaro-sway.download)
[![settings release](https://img.shields.io/github/v/release/manjaro-sway/desktop-settings)](https://github.com/Manjaro-Sway/desktop-settings/releases/latest)
[![lts](https://img.shields.io/badge/dynamic/json?label=lts&query=%24%5B%3A1%5D.packageName&url=https%3A%2F%2Fkernel-info.manjaro-sway.download%2F%3Fcategory%3Dlongterm)](https://github.com/Manjaro-Sway/manjaro-sway/releases/latest)
[![stable](https://img.shields.io/badge/dynamic/json?label=stable&query=%24%5B%3A1%5D.packageName&url=https%3A%2F%2Fkernel-info.manjaro-sway.download%2F%3Fcategory%3Dstable)](https://github.com/Manjaro-Sway/manjaro-sway/releases/latest)

![image](https://user-images.githubusercontent.com/4662748/212540664-1445ae40-96d2-48b6-92e1-d9c0d350b420.png)

We are building a manjaro sway edition - with the following principles:

- use a decent cli/tui solution
- convention overrideable by configuration
- prepare opt-out
- build everything automatically

## How to install

You can find the latest images on [manjaro-sway.download](https://manjaro-sway.download/).

You can create a bootable USB stick using [Etcher](https://www.balena.io/etcher/) or a similar tool.

Check out our [FAQ](SUPPORT.md) for additional hints.

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

### Contributing

There are lots of ways to contribute. 

- Give us a ⭐ here on github to increase our visibility
- Help collecting implementation ideas in [discussions](https://github.com/Manjaro-Sway/manjaro-sway/discussions)
- Implement ideas in our [desktop-settings](https://github.com/manjaro-sway/desktop-settings/tree/sway/community/sway) and [iso profile](https://github.com/manjaro-sway/iso-profiles/tree/sway/community/sway) and create pull requests
- Contribute to the documentation and help others in our chat
- Get in [touch](https://forum.manjaro.org/) with the broader Manjaro community.
- use the distribution on a daily basis, find and share solutions to problems you have. 
- get the manjaro packages before they are released to the general public by [switching to our "unstable" or "testing" branch](https://wiki.manjaro.org/index.php/Switching_Branches#Changing_to_another_branch) and report issues you face early on.

### Credits

- initial inspiration came from the [sway branch in the manjaro iso profiles repo](https://gitlab.manjaro.org/profiles-and-settings/iso-profiles/-/tree/sway)
- initially a lot of work got copied from the [manjaro sway arm overlay](https://gitlab.manjaro.org/manjaro-arm/applications/arm-profiles/-/tree/master/overlays/sway)
- the background image is [beautifully made by reddit user u/atlas-ark](https://www.reddit.com/r/wallpaper/comments/kmh680/1920x1080_all_resolutions_available_dark_light/?utm_source=share&utm_medium=web2x&context=3)
- the logo is a contribution by [André Vallestero](https://github.com/AndreVallestero)

### Donations

If you like our distribution and have some bucks to spare, please consider contributions to the projects and developers we rely on the most:

- for sway and wlroots, consider [Drew DeVault](https://drewdevault.com/)
- for waybar, consider [Alexis Rouillard](https://github.com/sponsors/Alexays)

### Contributors ✨

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://jonas-strassel.de/"><img src="https://avatars.githubusercontent.com/u/4662748?v=4?s=100" width="100px;" alt="Jonas Strassel"/><br /><sub><b>Jonas Strassel</b></sub></a><br /><a href="#infra-boredland" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=boredland" title="Code">💻</a> <a href="#maintenance-boredland" title="Maintenance">🚧</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/simon-bueler"><img src="https://avatars.githubusercontent.com/u/5940667?v=4?s=100" width="100px;" alt="Simon Büeler"/><br /><sub><b>Simon Büeler</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=simon-bueler" title="Code">💻</a> <a href="#maintenance-simon-bueler" title="Maintenance">🚧</a> <a href="#ideas-simon-bueler" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/AntonPicetti"><img src="https://avatars.githubusercontent.com/u/31367653?v=4?s=100" width="100px;" alt="Anton Picetti"/><br /><sub><b>Anton Picetti</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3AAntonPicetti" title="Bug reports">🐛</a> <a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=AntonPicetti" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Mathew-D"><img src="https://avatars.githubusercontent.com/u/44036272?v=4?s=100" width="100px;" alt="Mathew"/><br /><sub><b>Mathew</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3AMathew-D" title="Bug reports">🐛</a> <a href="#ideas-Mathew-D" title="Ideas, Planning, & Feedback">🤔</a> <a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=Mathew-D" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/bhartshorn"><img src="https://avatars.githubusercontent.com/u/56871?v=4?s=100" width="100px;" alt="Brandon Hartshorn"/><br /><sub><b>Brandon Hartshorn</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Abhartshorn" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://www.andrevallestero.com"><img src="https://avatars.githubusercontent.com/u/39736205?v=4?s=100" width="100px;" alt="Andre Vallestero"/><br /><sub><b>Andre Vallestero</b></sub></a><br /><a href="#design-AndreVallestero" title="Design">🎨</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://falco.dev"><img src="https://avatars.githubusercontent.com/u/1385470?v=4?s=100" width="100px;" alt="Rafael dos Santos Silva"/><br /><sub><b>Rafael dos Santos Silva</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=xfalcox" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://www.appelgriebsch.org"><img src="https://avatars.githubusercontent.com/u/6803419?v=4?s=100" width="100px;" alt="Andreas Gerlach"/><br /><sub><b>Andreas Gerlach</b></sub></a><br /><a href="#ideas-appelgriebsch" title="Ideas, Planning, & Feedback">🤔</a> <a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=appelgriebsch" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Chrysostomus"><img src="https://avatars.githubusercontent.com/u/12002226?v=4?s=100" width="100px;" alt="Matti Hyttinen"/><br /><sub><b>Matti Hyttinen</b></sub></a><br /><a href="#ideas-Chrysostomus" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/FallenChromium"><img src="https://avatars.githubusercontent.com/u/43214067?v=4?s=100" width="100px;" alt="FallenChromium"/><br /><sub><b>FallenChromium</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=FallenChromium" title="Code">💻</a> <a href="#ideas-FallenChromium" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://MuratovAS.github.io"><img src="https://avatars.githubusercontent.com/u/50487552?v=4?s=100" width="100px;" alt="Алексей Муратов "/><br /><sub><b>Алексей Муратов </b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3AMuratovAS" title="Bug reports">🐛</a> <a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=MuratovAS" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://www.mscneuro.uni-freiburg.de/"><img src="https://avatars.githubusercontent.com/u/33870649?v=4?s=100" width="100px;" alt="Hakan Yilmaz"/><br /><sub><b>Hakan Yilmaz</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Ahakanyi" title="Bug reports">🐛</a> <a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=hakanyi" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ahoneybun"><img src="https://avatars.githubusercontent.com/u/4884946?v=4?s=100" width="100px;" alt="Aaron Honeycutt"/><br /><sub><b>Aaron Honeycutt</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=ahoneybun" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/vncsna"><img src="https://avatars.githubusercontent.com/u/4673693?v=4?s=100" width="100px;" alt="Vinicius Aguiar"/><br /><sub><b>Vinicius Aguiar</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Avncsna" title="Bug reports">🐛</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Zeioth"><img src="https://avatars.githubusercontent.com/u/3357792?v=4?s=100" width="100px;" alt="Zeioth"/><br /><sub><b>Zeioth</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=Zeioth" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/xeruf"><img src="https://avatars.githubusercontent.com/u/13354331?v=4?s=100" width="100px;" alt="Janek"/><br /><sub><b>Janek</b></sub></a><br /><a href="#maintenance-xeruf" title="Maintenance">🚧</a> <a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Axeruf" title="Bug reports">🐛</a> <a href="#ideas-xeruf" title="Ideas, Planning, & Feedback">🤔</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/fraunos"><img src="https://avatars.githubusercontent.com/u/6673521?v=4?s=100" width="100px;" alt="Michał Wołoszyn"/><br /><sub><b>Michał Wołoszyn</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=fraunos" title="Code">💻</a> <a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Afraunos" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://annuel.nl"><img src="https://avatars.githubusercontent.com/u/4148154?v=4?s=100" width="100px;" alt="annuel"/><br /><sub><b>annuel</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=nnuel" title="Documentation">📖</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/aboettger"><img src="https://avatars.githubusercontent.com/u/206222?v=4?s=100" width="100px;" alt="Andreas Böttger"/><br /><sub><b>Andreas Böttger</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Aaboettger" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/AdriandMartin"><img src="https://avatars.githubusercontent.com/u/22200464?v=4?s=100" width="100px;" alt="Adrian Martin"/><br /><sub><b>Adrian Martin</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=AdriandMartin" title="Code">💻</a> <a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3AAdriandMartin" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/heapifyman"><img src="https://avatars.githubusercontent.com/u/274236?v=4?s=100" width="100px;" alt="heapifyman"/><br /><sub><b>heapifyman</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Aheapifyman" title="Bug reports">🐛</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Lyr-7D1h"><img src="https://avatars.githubusercontent.com/u/23296032?v=4?s=100" width="100px;" alt="Ivo"/><br /><sub><b>Ivo</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/commits?author=Lyr-7D1h" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://arkaitz.dev/"><img src="https://avatars.githubusercontent.com/u/56298377?v=4?s=100" width="100px;" alt="Arkaitz"/><br /><sub><b>Arkaitz</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Aarkaitz-dev" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/tobip"><img src="https://avatars.githubusercontent.com/u/3918330?v=4?s=100" width="100px;" alt="Tobias Paar"/><br /><sub><b>Tobias Paar</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Atobip" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/2L3R4"><img src="https://avatars.githubusercontent.com/u/40668751?v=4?s=100" width="100px;" alt="2L3R4"/><br /><sub><b>2L3R4</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3A2L3R4" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/dinkocar"><img src="https://avatars.githubusercontent.com/u/82665713?v=4?s=100" width="100px;" alt="dinkocar"/><br /><sub><b>dinkocar</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Adinkocar" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ishaanbhimwal"><img src="https://avatars.githubusercontent.com/u/79986754?v=4?s=100" width="100px;" alt="Ishaan Bhimwal"/><br /><sub><b>Ishaan Bhimwal</b></sub></a><br /><a href="https://github.com/manjaro-sway/manjaro-sway/issues?q=author%3Aishaanbhimwal" title="Bug reports">🐛</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors) specification. Contributions of any kind welcome!
