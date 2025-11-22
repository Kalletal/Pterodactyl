ROOT := $(CURDIR)
ARCH ?= geminilake
TCVERSION ?= 7.2
SYNO_SDK_IMAGE ?= synologytoolkit/dsm7.2:7.2-64570

PACKAGE := pterodactyl
SCRIPTS := scripts/package

.PHONY: setup package php-runtime runtime-tools wings clean distclean verify

setup:
	@ARCH=$(ARCH) TCVERSION=$(TCVERSION) SYNO_SDK_IMAGE=$(SYNO_SDK_IMAGE) bash $(SCRIPTS)/bootstrap.sh

php-runtime:
	@ARCH=$(ARCH) TCVERSION=$(TCVERSION) SYNO_SDK_IMAGE=$(SYNO_SDK_IMAGE) bash $(SCRIPTS)/build-php-runtime.sh

runtime-tools:
	@ARCH=$(ARCH) TCVERSION=$(TCVERSION) SYNO_SDK_IMAGE=$(SYNO_SDK_IMAGE) bash $(SCRIPTS)/build-runtime-tools.sh

wings:
	@ARCH=$(ARCH) TCVERSION=$(TCVERSION) SYNO_SDK_IMAGE=$(SYNO_SDK_IMAGE) bash $(SCRIPTS)/build-wings.sh

package: setup runtime-tools
	@ARCH=$(ARCH) TCVERSION=$(TCVERSION) SYNO_SDK_IMAGE=$(SYNO_SDK_IMAGE) bash $(SCRIPTS)/build-spk.sh

clean:
	@rm -rf build/logs dist/tmp

distclean: clean
	@rm -rf .build dist
