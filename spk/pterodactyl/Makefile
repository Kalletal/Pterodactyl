SPK_NAME = pteropanel
SPK_VERS = 1.11.6
SPK_REV = 3
SPK_ICON = src/pterodactyl.png
DSM_UI_DIR = app

DEPENDS = cross/pterodactyl-panel cross/wings

MAINTAINER = Synology Ptero Builders
MAINTAINER_URL = https://github.com/gilles/ProjetSPK
DESCRIPTION = Synology DS920+ ready Pterodactyl Panel with bundled Wings daemon and containerized stack helpers.
CHANGELOG = "Fix Docker images (use latest tags), request docker group membership for package user, run Wings as native binary."
DISPLAY_NAME = Ptero
HOMEPAGE = https://pterodactyl.io/
LICENSE = MIT

STARTABLE = yes
SERVICE_USER = auto
SERVICE_SETUP = src/service-setup.sh
SSS_SCRIPT = src/dsm-control.sh
# Port is configured dynamically via wizard - no static SERVICE_PORT to avoid conflicts
# User chooses port during installation, Docker Worker binds to it
FWPORTS = src/app/pteropanel.sc

WIZARDS_DIR = src/wizard
CONF_DIR = src/conf

SPK_DEPENDS = "php83>=8.3.0"
INSTALL_DEP_PACKAGES = ContainerManager

POST_STRIP_TARGET = ptero_extra_install

include ../../mk/spksrc.common.mk
include ../../mk/spksrc.spk.mk

.PHONY: ptero_extra_install
ptero_extra_install:
	# Panel application
	install -d -m 0755 $(STAGING_DIR)/share/panel
	tar -C $(WORK_DIR)/install/var/packages/$(SPK_NAME)/target/share/pterodactyl/panel -cf - . | tar -C $(STAGING_DIR)/share/panel -xf -
	# Wings binary
	install -d -m 0755 $(STAGING_DIR)/bin
	install -m 0755 $(WORK_DIR)/install/var/packages/$(SPK_NAME)/target/bin/wings $(STAGING_DIR)/bin/wings
	# Runtime assets
	install -d -m 0755 $(STAGING_DIR)/share/docker
	install -m 0644 src/docker-compose.yml $(STAGING_DIR)/share/docker/docker-compose.yml
	install -m 0644 src/panel.env.example $(STAGING_DIR)/share/panel.env.example
	install -m 0644 src/wings.config.example.yml $(STAGING_DIR)/share/wings.config.example.yml
	install -m 0644 src/bootstrap.sql $(STAGING_DIR)/share/bootstrap.sql
