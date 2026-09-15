# Maintainer: Philipp Schaffrath <philipp dot schaffrath at gmail dot com>

pkgname=phinger-cursors
pkgver=2.1
pkgrel=1
pkgdesc='Most likely the most over-engineered cursor theme.'
url='https://github.com/phisch/phinger-cursors'
license=('CC-BY-SA-4.0')
arch=('any')
source=("$pkgname-$pkgver.tar.bz2::${url}/releases/download/v${pkgver}/${pkgname}-variants.tar.bz2")
md5sums=('c633fcc6d7e8a765d1374acb4cf73e7c')
sha256sums=('ddb7310c62bf8e0e2798a24f8a867e4af7b17a39757ba45c85e13f3988f646fc')

package() {
    install -Ddm755 "$pkgdir/usr/share/icons"
    for dir in $(find . -mindepth 1 -maxdepth 1 -type d); do
        cp -dr --no-preserve=ownership "$dir" "$pkgdir/usr/share/icons/"
    done
}