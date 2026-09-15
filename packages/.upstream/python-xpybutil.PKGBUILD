# Maintainer: twa022 <twa022 at gmail dot com>

pkgname=python-xpybutil
pkgver=0.0.6
pkgrel=5
pkgdesc="An incomplete xcb-util port plus some extras"
arch=('any')
url="https://github.com/BurntSushi/xpybutil"
license=('custom:WTFPL')
depends=('python-xcffib')
makedepends=('python-setuptools')
source=("$pkgname-$pkgver.tar.gz::https://github.com/BurntSushi/xpybutil/archive/$pkgver.tar.gz")
sha512sums=('494b1181e280613ce9f1d0ca1322a21048eacc534ec242809050f9720d429d4d490029c755d6f181e9f95a0e2f318963d794a55f81601f5ebe975618a4e9fd82')

build() {
  cd xpybutil-$pkgver
  python setup.py build
}

package() {
  cd xpybutil-$pkgver
  python setup.py install --root="$pkgdir/" --optimize=1
  install -Dm664 COPYING "$pkgdir"/usr/share/licenses/$pkgname/COPYING
  mv "$pkgdir/usr/share/doc/"{,python-}xpybutil
}
