# Maintainer: Vitalij Berdinskih <vitalij_r2@outlook.com>

pkgname=swayshot 
pkgver=2.8.0
pkgrel=1
pkgdesc="Sway screenshots: screen, window or region. Also it uploads them to 0x0.st."
arch=("any")
url="https://github.com/vitalijr2/swayshot"
license=('GPL3')
depends=('sway' 'grim' 'slurp' 'jq')
optdepends=('wl-clipboard: copy the full path to clipboard'
	'xsel: copy the full path to clipboard'
	'xclip: copy the full path to clipboard'
	'curl: upload a screenshot to x0.at'
	'libnotify: show message with path or URL'
	'xdg-user-dirs: XDG user directories')
backup=(etc/sway/config.d/swayshot.conf)
source=("https://github.com/vitalijr2/$pkgname/archive/refs/tags/$pkgver.tar.gz")
sha256sums=('2d8eb8ca34ee448bb5e04d3e6632bc999fff976a5efd5c2feb194ad3b7e2585b')

package() {
	cd "$srcdir"/$pkgname-$pkgver

	install -d "$pkgdir"/etc/sway/config.d
	install -m 644 $pkgname.conf "$pkgdir"/etc/sway/config.d
	install -d "$pkgdir"/usr/bin
	install -m 755 $pkgname.sh "$pkgdir"/usr/bin/$pkgname
}
