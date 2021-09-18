DESTDIR ?= /
PREFIX ?= usr
BINDIR ?= $(PREFIX)/bin
CONFDIR ?= etc

install-yaps-add: yaps.add.sh
	install -v -D -m 755 yaps.add.sh 		$(DESTDIR)$(BINDIR)/yaps.add

install-yaps-build: yaps.build.sh
	install -v -D -m 755 yaps.build.sh 		$(DESTDIR)$(BINDIR)/yaps.build

install-yaps-remove: yaps.remove.sh
	install -v -D -m 755 yaps.remove.sh 	$(DESTDIR)$(BINDIR)/yaps.remove

install-yaps-trigger: yaps.trigger.sh
	install -v -D -m 755 yaps.trigger.sh 	$(DESTDIR)$(BINDIR)/yaps.trigger

install-yaps-config: yaps.conf
	install -v -D -m 644 yaps.conf 			$(DESTDIR)etc/yaps.conf

install-yaps-build-config: yaps.build.conf
	install -v -D -m 644 yaps.build.conf 	$(DESTDIR)etc/yaps.build.conf

#install-yaps-mirror: yaps.mirror
#	install -v -D -m 755 yaps.mirror    $(DESTDIR)etc/yaps.mirror

install-yaps: install-yaps-add install-yaps-build install-yaps-remove install-yaps-trigger #install-yaps-mirror
	install -v -D -m 755 yaps.sh 			$(DESTDIR)$(BINDIR)/yaps

install-config:	install-yaps-config install-yaps-build-config


install: install-yaps install-config
