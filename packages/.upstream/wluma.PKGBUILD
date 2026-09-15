# Maintainer: torculus <20175597+torculus@users.noreply.github.com>
# Contributor: Maxim Baz <archlinux at maximbaz dot com>

pkgname=wluma
pkgver=4.11.1
pkgrel=1
license=('ISC')
pkgdesc='Automatic brightness adjustment based on screen contents and ALS'
url='https://github.com/maximbaz/wluma'
arch=('x86_64' 'aarch64')
depends=('dbus' 'vulkan-icd-loader' 'systemd-libs' 'glibc' 'gcc-libs' 'v4l-utils')
optdepends=('vulkan-driver: for using capturer=wlroots in config.toml'
            'wayland: for using capturer=wlroots in config.toml')
makedepends=('cargo' 'clang' 'systemd' 'marked-man')
source=("${pkgname}-${pkgver}.tar.gz::https://github.com/max-baz/${pkgname}/archive/${pkgver}.tar.gz"
        "https://github.com/max-baz/${pkgname}/releases/download/${pkgver}/${pkgname}-${pkgver}.tar.gz.asc")
b2sums=('3eba7e941a11f459053018dc3eb59e23da6c41d3a3206ccf0684e8e1294da7da1a54fefd20295cafceb695ea8f7483822cf99472f2b701dd57c8d1b95fb57ce6'
        '6b9d7198debd31744bdf7d70496c0f4f945694fa927d538f1e3e5448d880da0c65d27a0bbac75cc4e7fb26d3a47f2d7bb513bae8c5147f92d28e1c75d0b72528')
validpgpkeys=('56C3E775E72B0C8B1C0C1BD0B5DB77409B11B601')

prepare() {
    cd ${pkgname}-${pkgver}
    export RUSTUP_TOOLCHAIN=stable
    cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"
}

build() {
    cd ${pkgname}-${pkgver}
    export RUSTUP_TOOLCHAIN=stable
    export CARGO_TARGET_DIR=target
    cargo build --frozen --release --all-features
    marked-man -i README.md -o "${pkgname}.7"
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
    install -Dm644 -t "${pkgdir}/usr/share/${pkgname}/examples" "config.toml"
}
