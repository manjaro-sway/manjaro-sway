# Maintainer: torculus <20175597+torculus@users.noreply.github.com>
# Contributor: Maxim Baz <archlinux at maximbaz dot com>

pkgname=wluma
pkgver=5.0.3
pkgrel=1
license=('ISC')
pkgdesc='Automatic brightness adjustment based on screen contents and ALS'
url='https://github.com/maximbaz/wluma'
arch=('x86_64' 'aarch64')
depends=('dbus' 'vulkan-icd-loader' 'systemd-libs' 'glibc' 'libgcc' 'v4l-utils' 'libpipewire')
optdepends=('vulkan-driver: for using capturer=wlroots in config.toml'
            'wayland: for using capturer=wlroots in config.toml')
makedepends=('cargo' 'clang' 'systemd' 'go-md2man')
source=("${pkgname}-${pkgver}.tar.gz::https://github.com/max-baz/${pkgname}/archive/${pkgver}.tar.gz"
        "https://github.com/max-baz/${pkgname}/releases/download/${pkgver}/${pkgname}-${pkgver}.tar.gz.asc")
b2sums=('40b89649ac3100c7961d99366f2225ed14f4cae6753648034f4a8515cc3d82d22c798a46898ac44fffadc184115ea75b0c78e5ab6105158c8b121cd7b94f50c3'
	'9b6e522c9694b5d3f0d995153272fe20d8a1a872cef543bad182e7490f20fb55ddcdb12a8fbcedf6f7ddc1cbe0dd9a31e22c50103f272bfd6dd080a2f808c76c')
validpgpkeys=('56C3E775E72B0C8B1C0C1BD0B5DB77409B11B601')
options=(!lto)

prepare() {
    cd ${pkgname}-${pkgver}
    export RUSTUP_TOOLCHAIN=stable
    cargo fetch --locked --target host-tuple
}

build() {
    cd ${pkgname}-${pkgver}
    export RUSTUP_TOOLCHAIN=stable
    export CARGO_TARGET_DIR=target
    cargo build --frozen --release --all-features
    go-md2man -in=README.md -out="${pkgname}.7"
    gzip "${pkgname}.7"
}

check() {
    cd ${pkgname}-${pkgver}
    export RUSTUP_TOOLCHAIN=stable
    cargo test --frozen --all-features
}

package() {
    cd ${pkgname}-${pkgver}
    install -Dm0755 -t "$pkgdir/usr/bin/" "target/release/$pkgname"
    install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
    install -Dm644 -t "${pkgdir}/usr/lib/udev/rules.d" "90-${pkgname}-backlight.rules"
    install -Dm644 -t "${pkgdir}/usr/lib/systemd/user" "${pkgname}.service"
    install -Dm644 -t "${pkgdir}/usr/share/doc/${pkgname}" "README.md"
    install -Dm644 -t "${pkgdir}/usr/share/man/man7" "${pkgname}.7.gz"
}
