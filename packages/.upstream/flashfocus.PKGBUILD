# Maintainer: Zaraksh Rahman <zarakshr at gmail dot com>
# Previous Maintainer: Bart Libert <bart plus aur at libert dot email>
# Contributor: Luis Martinez <luis dot martinez at disroot dot org>
# Contributor: Fenner Macrae <fmacrae.dev at gmail dot com>

pkgname=flashfocus
pkgver=2.9.0
pkgrel=1
pkgdesc="Simple focus animations for tiling window managers"
url="https://www.github.com/fennerm/flashfocus"
license=('MIT')
arch=('any')
depends=(
    'bash'
    'python'
    'python-click'
    'python-i3ipc'
    'python-marshmallow'
    'python-cffi'
    'python-xcffib'
    'python-xpybutil'
    'python-yaml')
optdepends=(
    	'i3-wm: compatible window manager'
    	'sway: compatible window manager'
    	'bspwm: compatible window manager'
    	'awesome: compatible window manager'
    	'xmonad: compatible window manager'
    	'picom: recommended compositor if using X-based window managers')
changelog=CHANGELOG.md
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('01c22e192f93808361c493b4a0bf2ae4d1077cd4411e8d80dec76085cb1e7476')

makedepends=(python-build python-installer python-wheel python-setuptools)

build() {
    cd "$pkgname-$pkgver"
    python -m build --wheel --no-isolation
}

package() {
    cd "$pkgname-$pkgver"
    python -m installer --destdir="$pkgdir" dist/*.whl
    install -Dvm644 LICENSE -t "$pkgdir/usr/share/licenses/$pkgname/"
    install -Dvm644 README.md -t "$pkgdir/usr/share/doc/$pkgname/"
    install -Dvm644 flashfocus.service -t "$pkgdir/usr/lib/systemd/user/"
}
