# Maintainer: Jonas Strassel <info@jonas-strassel.de>
pkgname="manjaro-sway-wallpapers"
pkgver=2.0.0
pkgrel=3
pkgdesc="Set of manjaro-related wallpapers"
arch=('any')
url="https://github.com/Manjaro-Sway/manjaro-sway-wallpapers"
license=('MIT')
source=(
    "https://raw.githubusercontent.com/AndreVallestero/sway-art/a94162ed4c2a94354dd6de26567924ba1c3e3a8c/manjaro-sway-small-wallpaper-3840x2160.png"
    "https://raw.githubusercontent.com/AndreVallestero/sway-art/a94162ed4c2a94354dd6de26567924ba1c3e3a8c/manjaro-sway-small-wallpaper-edged-3840x2160.png"
    "https://raw.githubusercontent.com/AndreVallestero/sway-art/a94162ed4c2a94354dd6de26567924ba1c3e3a8c/manjaro-sway-wallpaper-3840x2160.png"
    "AndreVallestero.LICENSE::https://raw.githubusercontent.com/AndreVallestero/sway-art/12f055b11a9ef9f302c18e5391e9307df3db7d9d/LICENSE"
)
md5sums=(
    '30c6e74280fed39ebdb23dc885c68bc1'
    '7d30d981a697535a8927f88e5f4df41f'
    'cc372e11f3e90eeb2c2d4f22deb3933e'
    '65d3616852dbf7b1a6d4b53b00626032'
)

prepare() {
    cp "$startdir"/static/*.png "$srcdir"/
}

package() {
    install -d "$pkgdir"/usr/share/backgrounds/manjaro-sway
    install *.png "${pkgdir}"/usr/share/backgrounds/manjaro-sway
    install *.LICENSE "${pkgdir}"/usr/share/backgrounds/manjaro-sway
}