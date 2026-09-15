# Maintainer: Zen Wen <zen.8841@gmail.com>
# Contributor: boltgolt <boltgolt@gmail.com>
# Contributor: Kelley McChesney <kelley@kelleymcchesney.us>
# Contributor: Andrey Kolchenko <andrey@kolchenko.me>
pkgname=pam-python
pkgver=1.0.8
pkgrel=4
pkgdesc='Python for PAM'
arch=('x86_64')
url='http://pam-python.sourceforge.net/'
license=('AGPL-3.0-or-later')
depends=(
  'pam'
  'python2'
)
makedepends=(
  'python-sphinx'
  'make'
)
source=(
  "https://downloads.sourceforge.net/project/pam-python/pam-python-${pkgver}-1/pam-python-${pkgver}.tar.gz"
)
sha256sums=('fc69d7717db0509111500a81053487fa7684e1be3b7d0ae2b51970b6fdc918f6')

prepare() {
  cd "${srcdir}/${pkgname}-${pkgver}"
  sed -i'' 's|LIBDIR ?= /lib/security|LIBDIR ?= /usr/lib/security|g' src/Makefile
  sed -i 's/-Werror//g' src/Makefile
  # sed -n '/^License/,/^--$/p' README.txt | grep -v -e '^License' -e '^-\+' > LICENSE
  sed -n '/^License/,/^--$/p' README.txt | awk '{sub(/^[ \t]+/, ""); lines[NR]=$0} END {for(i=3; i<=NR-3; i++) print lines[i]}' >LICENSE
}

build() {
  cd "${srcdir}/${pkgname}-${pkgver}"

  export CFLAGS+=" -D_GNU_SOURCE -Wno-error"

  PREFIX=/usr make
}

package() {
  cd "${srcdir}/${pkgname}-${pkgver}"
  PREFIX=/usr make DESTDIR="${pkgdir}" install
  install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}
