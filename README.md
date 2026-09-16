# Manjaro Sway Edition

[![lts](https://img.shields.io/badge/dynamic/json?label=lts&query=%24%5B%3A1%5D.packageName&url=https%3A%2F%2Fkernel.manjaro.download%2Fcategory%2Flongterm.json)](https://github.com/Manjaro-Sway/manjaro-sway/releases/latest)
[![stable](https://img.shields.io/badge/dynamic/json?label=stable&query=%24%5B%3A1%5D.packageName&url=https%3A%2F%2Fkernel.manjaro.download%2Fcategory%2Fstable.json)](https://github.com/Manjaro-Sway/manjaro-sway/releases/latest)

[![packages](https://github.com/manjaro-sway/manjaro-sway/actions/workflows/build-packages.yml/badge.svg)](https://github.com/manjaro-sway/manjaro-sway/actions/workflows/build-packages.yml)
[![iso](https://github.com/manjaro-sway/manjaro-sway/actions/workflows/build-iso.yml/badge.svg)](https://github.com/manjaro-sway/manjaro-sway/actions/workflows/build-iso.yml)

[![Matrix](https://img.shields.io/matrix/manjaro-sway:matrix.org)](https://matrix.to/#/#manjaro-sway:matrix.org)

![manjaro sway colors](https://github.com/manjaro-sway/manjaro-sway/assets/4662748/d0f7427d-bcfa-4949-985a-6789235b5641)

This is manjaro sway edition - built according to the following principles:

- use a decent cli/tui solution
- convention override-able by configuration
- prepare opt-out
- build everything in automation

## How to install

You can find the latest images on [sway.manjaro.download](https://sway.manjaro.download/).

You can create a boot-able USB stick using [Etcher](https://www.balena.io/etcher/) or a similar tool.

Check out our [FAQ](SUPPORT.md) for additional hints.

> **Note on release branches**
>
> We currently only publish images built against Manjaro's `unstable` branch. Sway doesn't carry the deep dependency-tree entanglements that the larger DE variants (KDE, GNOME, XFCE) have to manage when promoting packages from `unstable` → `testing` → `stable`, so for our edition `unstable` is generally a fine daily driver. If you'd rather track a slower-moving branch, you can [switch to `testing` or `stable`](https://wiki.manjaro.org/index.php/Switching_Branches#Changing_to_another_branch) after install.

## Noteworthy side-projects

Some projects evolved from the this sway distribution include:

- tons of [github actions](https://github.com/orgs/manjaro-contrib/repositories?q=actions) to orchestrate iso-/image- and package-building, as well as repo-orchestration
- [mjr.sh](https://mjr.sh) a little service for shortening links, available in Manjaro Sway as the `mjr` cli

## Development

### Sources

Everything this distribution builds lives in this repository:

- [`iso-profiles/community/sway`](iso-profiles/community/sway) — the ISO profile
- [`packages/manjaro-sway-settings/payload`](packages/manjaro-sway-settings/payload) — the desktop settings and skel
- [`packages/`](packages) — the PKGBUILDs of the pacman repository, with
  [`upstreams.yml`](packages/upstreams.yml) recording where each vendored one comes from
- [`worker/`](worker) and [`docs/`](docs) — what serves
  [sway.manjaro.download](https://sway.manjaro.download)

### How to Build

The ISO and the packages are built by
[`build-iso.yml`](.github/workflows/build-iso.yml) and
[`build-packages.yml`](.github/workflows/build-packages.yml). To build an ISO
locally with [manjaro-tools](https://gitlab.manjaro.org/tools/development-tools/manjaro-tools):

```bash
buildiso -p sway -f -b unstable
```

Before pushing a profile change, the cheap check the CI runs is worth running too:

```bash
python3 scripts/check_iso_packages.py
```

### Contributing

There are lots of ways to contribute.

- Give us a ⭐ here on github to increase our visibility
- Help collecting implementation ideas in [discussions](https://github.com/Manjaro-Sway/manjaro-sway/discussions)
- Implement ideas in the [desktop settings](packages/manjaro-sway-settings/payload) and the [iso profile](iso-profiles/community/sway) and create pull requests
- Contribute to the documentation and help others in our chat
- Get in [touch](https://forum.manjaro.org/) with the broader Manjaro community.
- Use the distribution on a daily basis, find and share solutions to problems you have.
- Get the manjaro packages before they are released to the general public by [switching to our "unstable" or "testing" branch](https://wiki.manjaro.org/index.php/Switching_Branches#Changing_to_another_branch) and report issues you face early on.

### Credits

- initial inspiration came from the [sway branch in the manjaro iso profiles repo](https://gitlab.manjaro.org/profiles-and-settings/iso-profiles/-/tree/sway)
- initially a lot of work got copied from the [manjaro sway arm overlay](https://gitlab.manjaro.org/manjaro-arm/applications/arm-profiles/-/tree/master/overlays/sway)
- the logo is a contribution by [André Vallestero](https://github.com/AndreVallestero)

### Donations

If you like our distribution and have some bucks to spare, please consider contributions to the projects and developers we rely on the most:

- for sway and wlroots, consider [Drew DeVault](https://drewdevault.com/)
- for waybar, consider [Alexis Rouillard](https://github.com/sponsors/Alexays)
