# Maintainer: Jamison Lahman <jamison+aur@lahman.dev>
# Contributor:
pkgname=zeit
pkgver=1.1.0
pkgrel=1
pkgdesc="Zeit, erfassen. A command line tool for tracking time. (https://codeberg.org/mrus/zeit)"
arch=('x86_64' 'aarch64')
url="https://github.com/mrusme/zeit"
license=('unknown')
depends=('glibc')
makedepends=('go' 'git')
_commit='c1c43e8ee28a6ec4e3e625a31dc5f787ccf8ae69'
source=("git+https://github.com/mrusme/zeit.git#commit=$_commit")
sha256sums=('SKIP')

prepare() {
  cd "$pkgname" || exit
  go mod download -modcacherw
}

build() {
  export CGO_CPPFLAGS="${CPPFLAGS}"
  export CGO_CFLAGS="${CFLAGS}"
  export CGO_CXXFLAGS="${CXXFLAGS}"
  export CGO_LDFLAGS="${LDFLAGS}"
  cd "$pkgname" || exit
  go build -buildmode=pie \
    -trimpath \
    -mod=readonly \
    -modcacherw \
    -ldflags='-s -w' \
    -o $pkgname \
    .
}

package() {
  cd "$pkgname" || exit
  install -Dm 755 $pkgname -t "$pkgdir/usr/bin"
  install -Dm 644 LICENSE -t "$pkgdir/usr/share/licenses/$pkgname"
  install -Dm 644 README.md -t "$pkgdir/usr/share/doc/$pkgname"
}
