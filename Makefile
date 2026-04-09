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
	@echo "Installed bare to $(BINDIR)/bare"
	@echo "To add to /etc/shells: sudo sh -c 'echo $(BINDIR)/bare >> /etc/shells'"

install-plugins:
	mkdir -p $(PLUGDIR)
	install -m755 plugins/ask $(PLUGDIR)/ask
	install -m755 plugins/suggest $(PLUGDIR)/suggest

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/bare
	rm -f $(DESTDIR)$(MANDIR)/bare.1

clean:
	rm -f bare bare.o

bench: bare
	./bare --bench

.PHONY: install install-plugins uninstall clean bench
