# Maintainer: Philipp Schaffrath <philipp dot schaffrath at gmail dot com>

pkgname=phinger-cursors
pkgver=2.2
pkgrel=1
pkgdesc='Most likely the most over-engineered cursor theme.'
url='https://github.com/phisch/phinger-cursors'
license=('CC-BY-SA-4.0')
arch=('any')
source=("$pkgname-$pkgver.tar.bz2::${url}/releases/download/v${pkgver}/${pkgname}-variants.tar.bz2")
md5sums=('10861addf60784e866dc47fe84f1c7b8')
sha256sums=('46d4cfc30a38c19cada3339027b5a78f7b0bf74f3220eba7001c4fdd9d5a6e56')

package() {
    install -Ddm755 "$pkgdir/usr/share/icons"
    for dir in $(find . -mindepth 1 -maxdepth 1 -type d); do
        cp -dr --no-preserve=ownership "$dir" "$pkgdir/usr/share/icons/"
    done
}