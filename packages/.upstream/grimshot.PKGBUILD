# Maintainer: Neptune <neptune650@proton.me>
# Contributor: Hugo Osvaldo Barrera <hugo@barrera.io>

pkgname=grimshot
pkgver=1.10
pkgrel=1
pkgdesc="A helper for screenshots within sway."
arch=("any")
url="https://github.com/OctopusET/sway-contrib"
license=('MIT')
depends=("grim" "slurp" "jq")
optdepends=('libnotify: Notify users when a screenshot is taken'
            'wl-clipboard: Copy screenshots')
makedepends=("scdoc")
source=(
  "$pkgname-$pkgver::https://raw.githubusercontent.com/OctopusET/sway-contrib/cd2cc4c4100ec3ed70ac5e3e8676d218788468a4/grimshot"
  "$pkgname-$pkgver.1.scd::https://raw.githubusercontent.com/OctopusET/sway-contrib/2a132b84460dcf28d042dc1a1cc6311b1918b43a/grimshot.1.scd"
)
sha256sums=('489d60e87178d0a9379072b508c438b42c8db5b9d2f48378f8ed196b0d736e26'
            'd940e87358033919ea175351210c1ca1a6b456a55e35f40b3d6039ba662c0fe8')

build() {
  cd "$srcdir/"
  scdoc < $pkgname-$pkgver.1.scd > grimshot.1
}

package() {
  cd "$srcdir/"

  install -Dm 644 grimshot.1 "$pkgdir/usr/share/man/man1/grimshot.1"
  install -Dm 755 $pkgname-$pkgver "$pkgdir/usr/bin/grimshot"
}
