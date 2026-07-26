# Maintainer: Geir Isene <g@isene.com>
pkgname=bare-shell
pkgver=0.2.43
pkgrel=1
pkgdesc="Interactive shell in x86_64 Linux assembly. No libc, pure syscalls. 8us startup."
arch=('x86_64')
url="https://github.com/isene/bare"
license=('Unlicense')
makedepends=('binutils' 'nasm')
source=("$pkgname-$pkgver.tar.gz::https://github.com/isene/bare/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')
install="$pkgname.install"

build() {
    cd "bare-$pkgver"
    make
    # makepkg doesn't strip this binary automatically, so do it explicitly.
    strip bare
}

package() {
    cd "bare-$pkgver"
    make PREFIX=/usr DESTDIR="$pkgdir" install
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    # Plugins
    install -Dm755 plugins/ask "$pkgdir/usr/share/bare/plugins/ask"
    install -Dm755 plugins/suggest "$pkgdir/usr/share/bare/plugins/suggest"
}
