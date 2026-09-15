# manjaro-iso-action

Tooling to build and distribute Manjaro on via Github Actions

## Usage example

This action ...

- installs the prerequisites to build Manjaro
- builds a ready to go Manjaro iso
- calculates hashes for the resulting image

It optionally provides:

- GPG-signing
- Distribution to Github Releases
- Upload of the unsplit image to S3-compatible object storage

### Dependencies

Python tooling is installed with `uv` at pinned versions, declared in the
`install-build-dependencies` step's `env` rather than buried in a shell
line. An unpinned dependency turns an upstream release into a failing
build on an unrelated pull request.

Ubuntu marks its system python externally-managed and refuses
`pip install --system` outright - `uv pip install --system` hits the same
refusal. So nothing is installed into the system python: meson and ninja
go in with `uv tool install`, and boto3 is supplied by `uv run --with` for
the one step that imports it.

This is a composite action, so it cannot assume the caller's runner has
mise - it installs uv itself. The repositories that consume it pin their
own tooling through `mise.toml`.

### Sources

`scripts/check-sources.py` parses the fetch steps out of `action.yml` and
checks that every clone resolves and lands in the directory the next line
enters, that every fetched file exists and looks like what the step does
with it, that every mirror the keyring resolver falls back through still
carries the keyring, that every mirror pacman falls back through still
serves the repositories, and that nothing the runner executes has CRLF
line endings. It runs on change and daily.

Three consecutive releases were broken by one-line faults here - a stale
URL, a clone landing in a differently-named directory, and a URL that
served an HTML page rather than the config it was installing. Each cost a
full ISO build to discover, around twenty-five minutes per edition, and
none of them needed a build to catch.

Everything the build clones or fetches comes from the `manjaro-contrib`
mirrors on GitHub rather than `gitlab.manjaro.org` directly: pacman,
manjaro-keyring, calamares-tools, manjaro-tools, manjaro-release,
pacman-mirrors and the default iso-profiles.

The upstream instance is the source of truth and the mirrors track it, but
it is not always reachable from a runner. A single unavailable moment took
out seven of fifteen builds with `remote: Token has expired` on a public
clone, and a build that has already spent twenty minutes should not die
fetching a keyring.

### Transient failures

Every `git clone`, `wget` and `curl` goes through `retry()` from
`scripts/retry.sh`, sourced by each step that fetches something - a
composite step is its own shell, so there is nowhere else to put it. Three
attempts, with the pause doubling after each, both overridable through
`RETRY_ATTEMPTS` and `RETRY_DELAY`. A command that fails every attempt
still fails the step with its own exit code.

Four full runs in one session died on faults that a second attempt would
have absorbed: a `403 Token has expired` from a clone of a public GitLab
repository, and `archlinux.org` answering 502 for roughly one request in
three. At around twenty-five minutes per edition, that is the cost of not
retrying.

`archlinux-keyring` is resolved by `scripts/install-archlinux-keyring.sh`
rather than fetched from `https://archlinux.org/packages/.../download`.
That URL is an HTML redirector rather than a mirror path, and was the least
reliable source in the action. The script reads `core.db` from the build
mirror, takes the current filename out of the package's `desc` entry, and
fetches the package from beside the database - a real mirror path, on the
mirror the build already depends on. An Arch mirror follows it, so one
mirror lagging or dropping out does not stop a build.

Keys named by `additional-trusted-gpg` are received from
`keys.openpgp.org`, falling back to `keyserver.ubuntu.com`; both carry the
same keys, and one being unreachable is not a reason to fail a build.

### Choosing the mirrors

`scripts/rank-mirrors.py` measures every mirror that carries all three
branches and rewrites `build-mirror` and `fallback-mirrors` with the
fastest four. `.github/workflows/rank-mirrors.yml` runs it weekly and
opens a pull request when the order changes, so the numbers are reviewed
rather than applied.

It runs on a runner because that is the only place the numbers mean
anything: the same mirror measured 12.8 MB/s from a laptop in Germany and
33-48 MiB/s from a GitHub runner, which is enough to invert a ranking.
Every mirror here is in the US, so a European measurement mostly ranks
them by distance to Europe.

Two details it gets right that a naive benchmark does not:

- the probe is a kernel package resolved from each mirror's own `core.db`,
  not `core.db` itself. That file is 154 KB, small enough that the result
  measures round trips rather than bandwidth.
- at most two mirrors come from one operator. Most of the fast ones are
  FCIX under different names, and a fallback list that is four names on one
  network fails together. Capping rather than forbidding keeps FCIX in,
  since excluding the fastest network to satisfy a rule would pick slow
  mirrors on principle.

Sync state is a gate, not a score: a mirror that lags is dropped however
fast it is, and among those in sync only throughput decides.

`.gitattributes` normalises line endings on checkin. Bash refuses a script
with CRLF endings and the error names the shell rather than the endings,
which is a cryptic way to lose a build a quarter of an hour in.

The retry above covers what the action itself fetches, but not what pacman
downloads inside `buildiso` - and a stalled mirror there took out four of
fifteen editions in one run, each about twenty-five minutes in:

```
error: failed retrieving file 'linux618-6.18.49-1-x86_64.pkg.tar.zst'
  from opencolo.mm.fcix.net : Operation too slow.
warning: too many errors from opencolo.mm.fcix.net, skipping for the
  remainder of this transaction
```

pacman had nothing to fall back to, because manjaro-tools points a chroot
at exactly one mirror: `mkchroot` rewrites `Include = /etc/pacman.d/mirrorlist`
to a single `Server =` built from `build_mirror`, and `chroot-run` overwrites
the mirrorlist outright. Listing alternatives there does not survive.

`XferCommand` does survive, because it sits in `[options]` rather than in a
repository section, so `scripts/pacman-xfer.sh` goes there and swaps the
host in the url pacman asked for. `fallback-mirrors` sets the list; it
defaults to three mirrors on the same sync tier as the build mirror and
under different operators, and emptying it restores plain downloads.

pacman runs `XferCommand` once per file - around eight hundred times for a
desktop transaction - and each run is a fresh process that remembers
nothing. A mirror that is down would therefore cost its connect timeout
every single time, which is hours of waiting and, in practice, pacman
giving up first. So a mirror that fails on transport is recorded under
`sick/` and skipped by the invocations that follow, for five minutes.
An HTTP error is not transport: a 404 means that mirror answered and the
file is simply not there, which says nothing about its health.

Having only one mirror was the original problem. Which mirror is first
also turned out to matter: measured against the same package, `forksystems`
and `coresite` sustain about 30 MB/s where `opencolo` manages 19.6, with
lower connect latency, and `opencolo` was the mirror that failed twice in
one evening. It is still in the list, just no longer in the hot path.

### Rootfs export

`export-rootfs: true` also writes `rootfs.tar.zst`, the ISO's own squashfs
layers stacked into a flat filesystem that `docker import` turns into a
runnable image. The path is exposed as the `rootfs-path` output.

An ISO is not a container image - it carries a kernel, an initramfs, a
bootloader and an installer, and it is booted rather than run. The desktop
inside it is another matter: manjaro-tools already builds it as layers
which calamares unpacks onto the target with no translation, so stacking
`rootfs.sfs`, `desktopfs.sfs` and `livefs.sfs` in that order gives the
filesystem a user gets after installing, without booting anything.

Dropped, because only a boot needs them: the kernel, its modules, the
firmware, the initramfs config and calamares. The mhwd layer is left out
too - it is a driver package repository, not part of the running system.

The export runs between `buildiso` and the line that deletes its work
directory, because the layers exist only in that window.

When object storage is configured it is uploaded beside the image, as
`<iso-name>.rootfs.tar.zst` - named after the image rather than
`rootfs.tar.zst`, which would collide between editions. It is not part of
the image's all-or-nothing set: that set exists because an image whose
signature is missing cannot be verified, and the rootfs says nothing about
the image. A rootfs that fails to upload takes only itself down and leaves
a verified image published.

### Chroot DNS

`buildiso` builds its overlays through `mkchroot` -> `basestrap`, which
copies the host keyring and mirrorlist but not `/etc/resolv.conf`, and
mounts the API filesystems with the `chroot_api_mount` variant that
carries no `resolv.conf` bind - unlike `chroot-run`, used for package
builds, which does. So the chroots resolve nothing, and both consequences
are silent because the build still succeeds:

- `pacman-mirrors` reports `Internet connection appears to be down` and
  generates the mirrorlist by random method rather than by ranking
- post-install scriptlets that fetch anything fail, so e.g.
  `libpamac-flatpak-plugin` ships without its remote configured

`scripts/enable-chroot-dns.sh` writes a resolver into the chroot from
`mkchroot`, between the directory being created and `basestrap` populating
it. That timing is the point: the packages' own post-install hooks resolve
names during installation - `pacman-mirrors` runs as hook 24 of 26 - so a
resolver written after the chroot is built arrives too late to help. Set
`chroot-nameservers` to override the default `1.1.1.1 8.8.8.8`.

### Object storage

A GitHub release asset is capped at 2 GB, so an image over that is uploaded
as a split zip (`.zip` + `.z01` + ...) and the release never carries the
`.iso` itself. Setting `r2-endpoint`, `r2-bucket` and the two credentials
uploads the image, its signature, hashes and package list to object
storage first, while the unsplit file is still on disk - so there is one
place the image can be downloaded without reassembly.

The upload is skipped entirely when no endpoint or bucket is given, so it
costs nothing for consumers that do not want it.

The set is all-or-nothing. An image whose signature or checksum failed to
upload cannot be verified, and anything serving a `latest` alias would
point at it regardless - so if any part of the set fails, whatever already
landed is removed and the previous build stays in place.

```yaml
      - uses: manjaro-contrib/action-buildiso@main
        with:
          edition: sway
          branch: unstable
          release-tag: ${{ needs.prepare-release.outputs.release_tag }}
          r2-endpoint: ${{ secrets.R2_ENDPOINT }}
          r2-access-key-id: ${{ secrets.R2_ACCESS_KEY_ID }}
          r2-secret-access-key: ${{ secrets.R2_SECRET_ACCESS_KEY }}
          r2-bucket: ${{ secrets.R2_BUCKET }}
          r2-prefix: ${{ needs.prepare-release.outputs.release_tag }}/
```

The following example is a minimal "matrix strategy" setup, that builds minimal and full images for cinnamon, gnome and builds the images each on stable and testing repositories. Refer [here](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions#jobsjob_idstrategymatrix) for more information on including / excluding permutations from matrix strategies.

All configuration options and defaults can be found [here](action.yml).

Instead of `manjaro/manjaro-iso-action@main`, please refer to the most current release (e.g. `manjaro/manjaro-iso-action@v1`).

```yaml
name: iso_build
on:
  workflow_dispatch:
  # remove if you don't want to build on a schedule
  schedule:
    - cron:  '30 6 1 * *'
  # remove if you don't want to build when commits are pushed to you main/master branch
  push:
    branches:
      - master
      - main

jobs:
  prepare-release:
    runs-on: ubuntu-20.04
    steps:
      # cancel already running instances of the same action on the currently working on branch
      - uses: styfle/cancel-workflow-action@0.9.0
        with:
          access_token: ${{ github.token }}
      - id: time
        uses: nanzm/get-time-action@v1.1
        with:
          format: 'YYYYMMDDHHmm'
    outputs:
      # generate a common tag to be used in all elements of the matrix strategy
      release_tag: ${{ steps.time.outputs.time }}      
  release:
    runs-on: ubuntu-20.04
    needs: prepare-release    
    strategy:
      matrix:
        ##### EDIT ME #####      
        EDITION: [cinnamon, gnome]
        BRANCH: [stable, testing]
        SCOPE: [minimal,full]
        ###################
    steps:
      # cancel already running instances of the same action on the currently working on branch
      - uses: styfle/cancel-workflow-action@0.9.0
        with:
          access_token: ${{ github.token }}
      - id: image-build
        uses: manjaro/manjaro-iso-action@main
        with:
          edition: ${{ matrix.edition }}
          branch: ${{ matrix.branch }}
          scope: ${{ matrix.scope }}
          version: "21.0"
          kernel: linux510
          code-name: "Ornara"
          # providing a release-tag allows for github releases
          release-tag: ${{ needs.prepare-release.outputs.release_tag }}
      # delete the github release in case of cancellation or failure
      # refer to .github/workflows/cleanup-test-release.yml for rollback strategies concerning the other distribution channels
      - name: rollback github release
        if: ${{ failure() || cancelled() }}
        run: |
          echo ${{ github.token }} | gh auth login --with-token
          gh release delete ${{ needs.prepare-release.outputs.release_tag }} -y --repo ${{ github.repository }}
          git push --delete origin ${{ needs.prepare-release.outputs.release_tag }}
```

### gpg signing

```yaml
- id: image-build
  uses: manjaro/manjaro-iso-action@main
  with:
    ...
    gpg-secret-key-base64: ${{ secrets.gpg_secret_base64 }}
    gpg-passphrase: ${{ secrets.GPG_PASSPHRASE }}
```

### caching

to get an idea how caching might work, please refer [here](.github/workflows/test.yml)

## Distribution channels

all distribution channels can be configured by setting / leaving out of their configuration variables.

### github release

```yaml
- id: image-build
  uses: manjaro/manjaro-iso-action@main
  with:
    ...
    release-tag: ${{ needs.prepare-release.outputs.release_tag }}
- name: rollback github release
  if: ${{ failure() || cancelled() }}
  run: |
    echo ${{ github.token }} | gh auth login --with-token
    gh release delete ${{ needs.prepare-release.outputs.release_tag }} -y --repo ${{ github.repository }}
    git push --delete origin ${{ needs.prepare-release.outputs.release_tag }}
```
