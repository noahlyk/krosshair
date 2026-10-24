# Maintainer: noahlyk <noahlykins@gmail.com>
pkgname=krosshair
pkgver=0.5.0
pkgrel=1
pkgdesc="Crosshair overlay for games on linux using Vulkan"
arch=('x86_64' 'aarch64')
url="https://github.com/noahlyk/krosshair"
license=('GPL3')
depends=('vulkan-icd-loader' 'libgl' 'libx11')
makedepends=('gcc' 'make' 'vulkan-headers')
install=krosshair.install
options=('!debug')

# Local builds from a git checkout report the tag, commit count and hash, the same as `make version`:
#   0.5.0+2.gbbd181e, or 0.5.0+2.gbbd181e.dirty with uncommitted changes.
# Anywhere without git the version above is used.
pkgver() {
    cd "$startdir"
    git rev-parse --git-dir >/dev/null 2>&1 || { echo "$pkgver"; return; }
    make -s version
}

build() {
    cd "$startdir"
    KROSSHAIR_VERSION="$pkgver" make release
}

package() {
    cd "$startdir"

    install -Dm755 lib/krosshair.so "$pkgdir/usr/lib/krosshair/krosshair.so"
    install -Dm644 krosshair.json "$pkgdir/usr/share/vulkan/implicit_layer.d/krosshair.json"
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"

    install -dm755 "$pkgdir/usr/share/krosshair/crosshairs"
    cp -r crosshairs/* "$pkgdir/usr/share/krosshair/crosshairs/" || true
}