SPK_NAME = pterodactyl_panel
SPK_VERS = 1.11.6
SPK_REV = 31
SPK_ICON = src/pterodactyl.png
DSM_UI_DIR = app

DEPENDS = cross/pterodactyl-panel cross/wings

MAINTAINER = Synology Ptero Builders
MAINTAINER_URL = https://github.com/gilles/ProjetSPK
DESCRIPTION = Pterodactyl Panel pour Synology avec Wings daemon intégré. Configuration Wings: 1) Connectez-vous au Panel 2) Admin → Nodes → Create New 3) Copiez la configuration YAML 4) Dans le Menu DSM cliquez sur Configurer Wings et collez la configuration.
CHANGELOG = "Ajout traduction française avec choix de langue dans le wizard. Nouvelles icônes officielles Pterodactyl."
DISPLAY_NAME = Pterodactyl Panel
HOMEPAGE = https://pterodactyl.io/
LICENSE = MIT

STARTABLE = yes
SERVICE_USER = auto
SERVICE_SETUP = src/service-setup.sh
SSS_SCRIPT = src/dsm-control.sh
# Port is configured dynamically via wizard - no static SERVICE_PORT to avoid conflicts
# User chooses port during installation, Docker Worker binds to it
FWPORTS = src/app/pterodactyl_panel.sc

WIZARDS_DIR = src/wizard
CONF_DIR = src/conf

# PHP is included in the Docker image - no system PHP dependency needed
# Only ContainerManager (Docker) is required
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
	# DSM UI config and images
	install -d -m 0755 $(STAGING_DIR)/app/images
	install -m 0644 src/app/config $(STAGING_DIR)/app/config
	install -m 0644 src/app/images/*.png $(STAGING_DIR)/app/images/
	# Wings configuration CGI (DSM popup interface)
	install -m 0755 src/ui/wings-config.cgi $(STAGING_DIR)/app/wings-config.cgi
	# Loading page
	install -m 0644 src/loading.html $(STAGING_DIR)/share/loading.html
	install -m 0755 src/loading-server.sh $(STAGING_DIR)/bin/loading-server.sh
	# French translation files
	install -d -m 0755 $(STAGING_DIR)/share/lang/fr
	install -d -m 0755 $(STAGING_DIR)/share/lang/fr/admin
	install -d -m 0755 $(STAGING_DIR)/share/lang/fr/command
	install -d -m 0755 $(STAGING_DIR)/share/lang/fr/dashboard
	install -d -m 0755 $(STAGING_DIR)/share/lang/fr/server
	cp -r src/lang/fr/*.php $(STAGING_DIR)/share/lang/fr/
	cp -r src/lang/fr/admin/*.php $(STAGING_DIR)/share/lang/fr/admin/
	cp -r src/lang/fr/command/*.php $(STAGING_DIR)/share/lang/fr/command/
	cp -r src/lang/fr/dashboard/*.php $(STAGING_DIR)/share/lang/fr/dashboard/
	cp -r src/lang/fr/server/*.php $(STAGING_DIR)/share/lang/fr/server/
