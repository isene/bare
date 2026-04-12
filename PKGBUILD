# Maintainer: Geir Isene <g@isene.com>
pkgname=bare-shell
pkgver=0.2.6
pkgrel=1
pkgdesc="Interactive shell in x86_64 Linux assembly. No libc, pure syscalls. 8us startup."
arch=('x86_64')
url="https://github.com/isene/bare"
license=('Unlicense')
makedepends=('nasm')
source=("$pkgname-$pkgver.tar.gz::https://github.com/isene/bare/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')

build() {
    cd "bare-$pkgver"
    make
}

package() {
    cd "bare-$pkgver"
    make DESTDIR="$pkgdir" install
    install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    # Plugins
    install -Dm755 plugins/ask "$pkgdir/usr/share/bare/plugins/ask"
    install -Dm755 plugins/suggest "$pkgdir/usr/share/bare/plugins/suggest"
}
