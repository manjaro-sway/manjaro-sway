pkgname=pacman-log-orphans-hook
pkgver=1.1
pkgrel=2
pkgdesc='hook to check whether there are any packages marked as unrequired (orphans) via pacman -Qttdq after every pacman run'
arch=(any)
depends=()
source=(log-orphans.hook)
sha256sums=('d7ea266963924c72d2546682c32f15c11486368f294871be469b6968256ab8d5')

package() {
    install -Dm0644 -t "$pkgdir/usr/share/libalpm/hooks/" ${source[0]}
}
