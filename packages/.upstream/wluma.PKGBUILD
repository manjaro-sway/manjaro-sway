# Maintainer: torculus <20175597+torculus@users.noreply.github.com>
# Contributor: Maxim Baz <archlinux at maximbaz dot com>

pkgname=wluma
pkgver=5.0.4
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
b2sums=('d6525cc63c46230717d6e2d684183160f83f14312339b07277cd2f7c23c2d05f67a5703398b546fa51f92d34a877ff9a47b9cf275700334ec25017acf46fd94c'
	'db673d5ee6d0cd8345ad429467e8c9ce4c7d10c01efb148f01f4b94b13042d03908ae471fe6f16be18b6741f6ac12f27bf15b2468f493149ce0f729bc89ec22f')
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
