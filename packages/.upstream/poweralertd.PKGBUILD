# Maintainer: Carlo Abelli <carlo@abelli.me>
# Contributor: Mark Wagie <mark dot wagie at tutanota dot com>
# Contributor: Stefan Tatschner <stefan@rumpelsepp.org>

pkgname=poweralertd
pkgver=0.3.0
pkgrel=1
pkgdesc="UPower-powered power alerter"
arch=(x86_64)
url=https://sr.ht/~kennylevinsen/poweralertd
license=(GPL-3.0-only)
depends=(glibc systemd-libs upower)
makedepends=(meson scdoc)
optdepends=("mako: notification daemon")
source=("$pkgname-$pkgver.tar.gz::https://git.sr.ht/~kennylevinsen/poweralertd/archive/$pkgver.tar.gz")
sha256sums=(5b2a1d0fefab62e5ddb5784f2cd3d330f36b3cb5260936f5051f6ff89d8abc3f)

build() {
  arch-meson "$pkgname-$pkgver" build
  meson compile -C build
}

package() {
  meson install -C build --destdir "$pkgdir"
}
