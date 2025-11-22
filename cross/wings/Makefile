PKG_NAME = wings
PKG_VERS = 1.11.5
PKG_EXT = tar.gz
PKG_DIST_NAME = v$(PKG_VERS).$(PKG_EXT)
PKG_DIST_SITE = https://github.com/pterodactyl/wings/archive/refs/tags
PKG_DIR = $(PKG_NAME)-$(PKG_VERS)
EXTRACT_PATH = $(WORK_DIR)

BUILD_DEPENDS = native/go

HOMEPAGE = https://pterodactyl.io/
COMMENT  = Daemon responsible for hosting game servers for the Pterodactyl panel
LICENSE  = MIT

COMPILE_TARGET = wings_compile
INSTALL_TARGET = wings_install

UNSUPPORTED_ARCHS = $(ARMv5_ARCHS) $(ARMv7_ARCHS) $(ARMv8_ARCHS) $(i686_ARCHS)

include ../../mk/spksrc.cross-go.mk

GO_SRC_DIR = $(EXTRACT_PATH)/$(PKG_DIR)
GO_BIN = $(GO_SRC_DIR)/wings
GO_LDFLAGS = -s -w

.PHONY: wings_compile wings_install

wings_compile:
	cd $(GO_SRC_DIR) && env $(filter-out GOARCH=%, $(ENV)) CGO_ENABLED=0 go build -ldflags "$(GO_LDFLAGS)" -o wings .

wings_install:
	install -d -m 0755 $(STAGING_INSTALL_PREFIX)/bin
	install -m 0755 $(GO_BIN) $(STAGING_INSTALL_PREFIX)/bin/wings
