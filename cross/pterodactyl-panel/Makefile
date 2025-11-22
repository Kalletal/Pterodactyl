PKG_NAME = pterodactyl-panel
PKG_VERS = 1.11.6
PKG_EXT = tar.gz
PKG_DIST_NAME = panel.$(PKG_EXT)
PKG_DIST_SITE = https://github.com/pterodactyl/panel/releases/download/v$(PKG_VERS)
PKG_DIST_FILE = $(PKG_DIST_NAME)
PKG_DIR = .
EXTRACT_PATH = $(WORK_DIR)/panel-src

DEPENDS =

HOMEPAGE = https://pterodactyl.io/
COMMENT  = Laravel-based management panel for running game servers with Wings
LICENSE  = MIT

INSTALL_TARGET = pterodactyl_panel_install

UNSUPPORTED_ARCHS = $(ARMv5_ARCHS) $(ARMv7_ARCHS) $(ARMv8_ARCHS)

include ../../mk/spksrc.archs.mk
include ../../mk/spksrc.install-resources.mk

.PHONY: pterodactyl_panel_install
pterodactyl_panel_install:
	install -d -m 0755 $(STAGING_INSTALL_PREFIX)/share/pterodactyl/panel
	tar -C $(EXTRACT_PATH) -cf - . | tar -C $(STAGING_INSTALL_PREFIX)/share/pterodactyl/panel -xf -
