.PHONY: all clean clean-native run release build prepare compile config-release config-restore refresh-core-plugin refresh-store-plugin urn

# non-versioned include
-include vars.mk

export SHELL := /bin/bash
export BUILD := build

mkdir = @mkdir -p $(dir $@)

MOBILE_VERSION = $(shell cat config.xml \
					| grep '^<widget' \
					| sed -E 's|^.*version="([^"]+)".*|\1|')

allcss = $(shell find ../js/css/ -name "*.css" \
			| grep -v 'reset.css')
alljs = $(shell echo "../js/main.js" \
			&& find ../js/{config,controllers,handlers,lib,models} -name "*.js" \
			| grep -v '(ignore|\.thread\.)')

IOS_NATIVE = $(shell find native/ -type f -name "*.a" | sed 's|native/|platforms/ios/Turtl/Plugins/com.lyonbros.turtlcore/|')

all: www/index.html

platforms/ios/libs/%/libturtl_core.so: native/%/libturtl_core.so
platforms/ios/Turtl/Plugins/com.lyonbros.turtlcore/%.a: native/%.a
	$(mkdir)
	cp $^ $@

run: all $(IOS_NATIVE) www/cacert.js
	./scripts/cordova.sh run android

platforms/android/release-signing.properties: scripts/release-signing.properties.tpl
	cat $< \
		| sed "s|{{ANDROID_SIGN_KEYSTORE}}|$(ANDROID_SIGN_KEYSTORE)|g" \
		| sed "s|{{ANDROID_SIGN_ALIAS}}|$(ANDROID_SIGN_ALIAS)|g" \
		> $@

release: BUILDFLAGS += --release
release: platforms/android/release-signing.properties config-release build config-restore

build: compile

compile: prepare
	./scripts/cordova.sh compile android $(BUILDFLAGS)

prepare: all $(ANDROID_NATIVE) www/cacert.js
	./scripts/cordova.sh prepare android $(BUILDFLAGS)

www/cacert.js: scripts/cacert.pem
	@echo "- $@: $^"
	@echo "var turtl_core_openssl_pem = [" > $@
	@cat $^ | sed 's|^|"|g' | sed 's|$$|",|g' >> $@
	@echo "].join('\n');" >> $@

config-release: all
	@mkdir -p $(BUILD)
	cp www/config.js $(BUILD)/config.js.tmp
	cp www/config.live.js www/config.js

config-restore:
	mv $(BUILD)/config.js.tmp www/config.js

www/app/index.html: $(alljs) $(allcss) ../js/index.html
	$(mkdir)
	@cd ../js && make
	@echo "- rsync project: " $?
	@rsync \
			-azz \
			--exclude=node_modules \
			--exclude=.git \
			--exclude=tests \
			--delete \
			--delete-excluded \
			--checksum \
			../js/ \
			www/app
	@touch $@

www/version.js: ./scripts/gen-index ./config.xml
	@echo "- www/version.js: " $?
	@echo "var cordova_app_version = '$(MOBILE_VERSION)';" > www/version.js

www/config-core.js: ../core/config.yaml.default
	@echo -n "var turtl_core_config = " > $@
	./node_modules/.bin/js-yaml $^ >> $@

# if the app's index changed, we know to change this one
www/index.html: www/app/index.html ./scripts/gen-index www/version.js www/config-core.js
	@echo "- index.html: " $?
	@./scripts/gen-index

refresh-core-plugin:
	cordova plugin remove com.lyonbros.turtlcore
	cordova plugin add bundle/cordova-plugin-turtl-core/

refresh-store-plugin:
	cordova plugin remove com.lyonbros.turtlstore
	cordova plugin add bundle/cordova-plugin-turtl-store/

refresh-share-plugin:
	cordova plugin remove cc.fovea.cordova.openwith
	cordova plugin add bundle/cordova-plugin-openwith/

urn:
	@echo "Is there a Ralphs around here?"

clean:
	rm -rf www/app www/config-core.js www/index.html www/version.js www/cacert.js
	rm -rf $(BUILD)
	rm -rf platforms/android/build platforms/android/CordovaLib/build
	rm -f www/index.html

clean-native:
	find native -name "*.so" -exec rm -f {} \;

