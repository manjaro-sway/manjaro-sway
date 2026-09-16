pkgname=idlehack
pkgver=0.r21
pkgrel=1
pkgdesc="Monitor dbus and inhibit swayidle when Firefox or Chromium request it"
arch=('i686' 'x86_64' 'aarch64')
url="https://github.com/loops/idlehack"
license=('custom:ICS')
provides=('idlehack' 'idlehack-git')
conflicts=('idlehack-git')
_commit="4f7c11a56cfc4346fee6f710419122b460ed65a4"
source=("$pkgname::git+https://github.com/loops/idlehack.git#commit=$_commit")
sha256sums=('SKIP')
depends=('libx11' 'dbus' 'systemd-libs')
makedepends=('git' 'cmake' 'pkgconf')

pkgver() {
    cd "$pkgname" || return 1
    printf "0.r%s" "$(git rev-list --count HEAD)"
}

build() {
    cmake -B build -S "$srcdir/$pkgname" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBEXECDIR=bin
    cmake --build build
}

package() {
    DESTDIR="$pkgdir" cmake --install build

    # Move service file to the correct Arch Linux location
    install -dm755 "$pkgdir/usr/lib/systemd/user"
    mv "$pkgdir/etc/systemd/user/idlehack.service" \
        "$pkgdir/usr/lib/systemd/user/"
    rmdir --ignore-fail-on-non-empty -p "$pkgdir/etc/systemd/user"
}
