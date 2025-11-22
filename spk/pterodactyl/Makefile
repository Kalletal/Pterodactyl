SPK_NAME = pterodactyl
SPK_VERS = 1.11.6
SPK_REV = 1
SPK_ICON = src/pterodactyl.png
DSM_UI_DIR = app

DEPENDS = cross/pterodactyl-panel cross/wings

MAINTAINER = Synology Ptero Builders
MAINTAINER_URL = https://github.com/gilles/ProjetSPK
DESCRIPTION = Synology DS920+ ready Pterodactyl Panel with bundled Wings daemon and containerized stack helpers.
CHANGELOG = "Initial Synology DS920+ focused build."
DISPLAY_NAME = Pterodactyl
HOMEPAGE = https://pterodactyl.io/
LICENSE = MIT

STARTABLE = yes
SERVICE_USER = auto
SERVICE_SETUP = src/service-setup.sh
SSS_SCRIPT = src/dsm-control.sh
SERVICE_PORT = 8080
SERVICE_PORT_TITLE = Panel (HTTP)
SERVICE_PORT_PROTOCOL = http
SERVICE_PORT_ALL_USERS = true
SERVICE_CERT = pterodactyl
ADMIN_PORT = $(SERVICE_PORT)
FWPORTS = src/app/pterodactyl.sc

WIZARDS_DIR = src/wizard
CONF_DIR = src/conf

SPK_DEPENDS = "php83>=8.3:app/php83"

POST_STRIP_TARGET = pterodactyl_extra_install

include ../../mk/spksrc.common.mk
include ../../mk/spksrc.spk.mk

.PHONY: pterodactyl_extra_install
pterodactyl_extra_install:
	# Panel application
	install -d -m 0755 $(STAGING_DIR)/share/panel
	tar -C $(WORK_DIR)/install/var/packages/pterodactyl/target/share/pterodactyl/panel -cf - . | tar -C $(STAGING_DIR)/share/panel -xf -
	# Wings binary
	install -d -m 0755 $(STAGING_DIR)/bin
	install -m 0755 $(WORK_DIR)/install/var/packages/pterodactyl/target/bin/wings $(STAGING_DIR)/bin/wings
	# Runtime assets
	install -d -m 0755 $(STAGING_DIR)/share/docker
	install -m 0644 src/docker-compose.yml $(STAGING_DIR)/share/docker/docker-compose.yml
	install -m 0644 src/panel.env.example $(STAGING_DIR)/share/panel.env.example
	install -m 0644 src/wings.config.example.yml $(STAGING_DIR)/share/wings.config.example.yml
	install -m 0644 src/bootstrap.sql $(STAGING_DIR)/share/bootstrap.sql
