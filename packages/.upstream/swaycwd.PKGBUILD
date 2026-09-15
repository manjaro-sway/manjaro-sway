# Maintainer: Julian Daube <joposter at gmail dot com>
# Contributer: Julian Daube <joposter at gmail dot com>


pkgname=swaycwd
pkgdesc="alternative to xcwd for swayvm"
pkgrel=1
pkgver=1.1
url="https://webcache.googleusercontent.com/search?q=cache:fXlJ80wnYwgJ:https://www.reddit.com/r/swaywm/comments/ayedi1/opening_terminals_at_the_same_directory/+&cd=1&hl=de&ct=clnk&gl=de&client=firefox-b-d"
arch=("any")

source=("swaycwd")
depends=("sway" "bash" "jq" "procps")

package() {
	mkdir -p "$pkgdir/usr/bin"
	install -m 755 "$srcdir/swaycwd" "$pkgdir/usr/bin/swaycwd"
}
md5sums=('fad6fddc15abd75e7ca7760553dd2a28')
md5sums=('b26f324308016ded12e36d54540d6bd2')
