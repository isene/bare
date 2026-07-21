PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man/man1
PLUGDIR = $(HOME)/.bare/plugins

bare: bare.asm
	nasm -f elf64 bare.asm -o bare.o
	ld bare.o -o bare
	rm -f bare.o

install: bare
	install -Dm755 bare $(DESTDIR)$(BINDIR)/bare
	install -Dm644 bare.1 $(DESTDIR)$(MANDIR)/bare.1
	install -Dm755 bare-open $(DESTDIR)$(BINDIR)/bare-open
	@echo "Installed bare to $(BINDIR)/bare"
	@echo "Installed bare-open to $(BINDIR)/bare-open (mime-aware file dispatcher)"
	@echo "To add to /etc/shells: sudo sh -c 'echo $(BINDIR)/bare >> /etc/shells'"

install-plugins:
	mkdir -p $(PLUGDIR)
	install -m755 plugins/ask $(PLUGDIR)/ask
	install -m755 plugins/suggest $(PLUGDIR)/suggest

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/bare
	rm -f $(DESTDIR)$(BINDIR)/bare-open
	rm -f $(DESTDIR)$(MANDIR)/bare.1

clean:
	rm -f bare bare.o

bench: bare
	./bare --bench

.PHONY: install install-plugins uninstall clean bench deb

# ── Debian package ─────────────────────────────────────────────────────
# Version comes from the README badge (the repo's single version marker).
VERSION := $(shell grep -oP 'version-\K[0-9.]+(?=-blue)' README.md)

deb: bare
	rm -rf pkgroot
	$(MAKE) install DESTDIR=$(CURDIR)/pkgroot PREFIX=/usr
	install -Dm644 LICENSE pkgroot/usr/share/doc/bare/copyright
	install -d pkgroot/DEBIAN
	printf 'Package: bare\nVersion: $(VERSION)\nArchitecture: amd64\nMaintainer: Geir Isene <g@isene.com>\nSection: shells\nPriority: optional\nHomepage: https://github.com/isene/bare\nDescription: Interactive shell in x86_64 assembly\n No libc, no runtime, pure syscalls. Single static binary with\n microsecond startup: prompt with git integration, tab completion,\n syntax highlighting, nicks, bookmarks, themes, plugins.\n' > pkgroot/DEBIAN/control
	printf '#!/bin/sh\nset -e\nif command -v add-shell >/dev/null 2>&1; then add-shell /usr/bin/bare; fi\n' > pkgroot/DEBIAN/postinst
	printf '#!/bin/sh\nset -e\nif command -v remove-shell >/dev/null 2>&1; then remove-shell /usr/bin/bare; fi\n' > pkgroot/DEBIAN/prerm
	chmod 755 pkgroot/DEBIAN/postinst pkgroot/DEBIAN/prerm
	dpkg-deb --build --root-owner-group pkgroot bare_$(VERSION)_amd64.deb
	rm -rf pkgroot
