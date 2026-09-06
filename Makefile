LIBRARY = lib/krosshair.so

CCFLAGS = -Wall -std=c99 -fPIC -shared -I./include/
LDFLAGS = -ldl -lm

# Debug build by default; use `make release` or `make RELEASE=1` for release
ifdef RELEASE
CCFLAGS += -O2 -DNDEBUG
else
CCFLAGS += -ggdb
endif

SOURCES = $(shell find src -type f -name "*.c")

BUILD_DIR = build
FLATPAK_BUILD_DIR = $(BUILD_DIR)/flatpak
FLATPAK_BUILD_DIR_INTERMEDIATE = $(FLATPAK_BUILD_DIR)/intermediate
FLATPAK_EXPORT_DIR = $(FLATPAK_BUILD_DIR_INTERMEDIATE)/export

FLATPAK_BUNDLE_ID = org.freedesktop.Platform.VulkanLayer.krosshair
FLATPAK_VERSIONS = 24.08 25.08 26.08
FLATPAK_LIB_PATH = /usr/lib/extensions/vulkan/krosshair/lib/krosshair.so
KROSSHAIR_STD_PATH = /usr/lib/krosshair/krosshair.so
FLATPAK_MANIST_FILE = flatpak/$(FLATPAK_BUNDLE_ID).yml
FLATPAK_METAINFO_FILE = flatpak/$(FLATPAK_BUNDLE_ID).metainfo.xml
PKGVERSION := $(shell grep -m1 '^pkgver=' PKGBUILD | cut -d= -f2)

# Detect if flathub is available at user level; fall back to system-level
FLATPAK_USER_REMOTE := $(shell flatpak --user remotes 2>/dev/null | grep -q flathub && echo 1)

ifeq ($(FLATPAK_USER_REMOTE),1)
  FLATPAK_INSTALL = flatpak install --user -y
else
  FLATPAK_INSTALL = sudo flatpak install -y
endif


.PHONY: all release clean install flatpak-build flatpak-install

all:
	mkdir -p lib
	$(CC) $(CCFLAGS) $(SOURCES) $(LDFLAGS) -o $(LIBRARY)

release:
	$(MAKE) RELEASE=1 all

install:
	sudo mkdir -p /usr/lib/krosshair
	sudo cp $(LIBRARY) /usr/lib/krosshair/krosshair.so
	sudo cp krosshair.json /usr/share/vulkan/implicit_layer.d/krosshair.json

clean:
	rm -f $(LIBRARY)
	rm -rf $(BUILD_DIR)

# Builds the flatpak into $(BUILD_DIR) (does NOT install it on the host).
flatpak-build:
	mkdir -p $(FLATPAK_BUILD_DIR)

	# Check and abort if the manifest, metainfo, or krosshair.json contain uncommitted changes. This is necessary as the build will temporarily modify the files during the build.
	git diff --exit-code $(FLATPAK_MANIST_FILE) $(FLATPAK_METAINFO_FILE) krosshair.json || { echo "ERROR: $(FLATPAK_MANIST_FILE), $(FLATPAK_METAINFO_FILE), or krosshair.json has uncommitted changes"; exit 1; }

	# Modify the metainfo file and krosshair.json for the flatpak build.
	sed -i "s|<release version=\"[^\"]*\" date=\"[^\"]*\"/>|<release version=\"$(PKGVERSION)\" date=\"$$(date +%Y-%m-%d)\"/>|" $(FLATPAK_METAINFO_FILE) && \
	sed -i "s|$(KROSSHAIR_STD_PATH)|$(FLATPAK_LIB_PATH)|" krosshair.json && \
	for VER in $(FLATPAK_VERSIONS); do \
		echo -e "\n-----\nBuilding flatpak for version \"$$VER\"...\n-----\n"; \
		mkdir -p $(FLATPAK_BUILD_DIR_INTERMEDIATE)/$$VER || exit 1; \
		sed -i "s|^branch:.*|branch: \"$$VER\"|" $(FLATPAK_MANIST_FILE) || exit 1; \
		sed -i "s|^runtime-version:.*|runtime-version: \"$$VER\"|" $(FLATPAK_MANIST_FILE) || exit 1; \
		# flatpak SDK install \
		echo -e "\n-----\nRunning flatpak install for \"org.freedesktop.Sdk//$$VER\"...\n-----\n"; \
		$(FLATPAK_INSTALL) flathub org.freedesktop.Sdk//$$VER org.freedesktop.Platform//$$VER || exit 1; \
		# flatpak-builder \
		echo -e "\n-----\nRunning flatpak-builder for \"$$VER\"...\n-----\n"; \
		flatpak-builder --force-clean $(FLATPAK_BUILD_DIR_INTERMEDIATE)/$$VER $(FLATPAK_MANIST_FILE) || exit 1; \
		# flatpak build-export \
		echo -e "\n-----\nRunning flatpak build-export for \"$$VER\"...\n-----\n"; \
		flatpak build-export $(FLATPAK_EXPORT_DIR) $(FLATPAK_BUILD_DIR_INTERMEDIATE)/$$VER $$VER || exit 1; \
		# flatpak build-bundle \
		echo -e "\n-----\nRunning flatpak build-bundle for \"$$VER\"...\n-----\n"; \
		flatpak build-bundle --runtime $(FLATPAK_EXPORT_DIR) $(FLATPAK_BUILD_DIR)/$(FLATPAK_BUNDLE_ID)_$$VER.flatpak $(FLATPAK_BUNDLE_ID) $$VER || exit 1; \
	done && \
	git checkout -- $(FLATPAK_MANIST_FILE) $(FLATPAK_METAINFO_FILE) krosshair.json

# Installs the flatpak (detects user vs system level automatically)
flatpak-install: flatpak-build
	for VER in $(FLATPAK_VERSIONS); do \
		$(FLATPAK_INSTALL) --reinstall $(FLATPAK_BUILD_DIR)/$(FLATPAK_BUNDLE_ID)_$$VER.flatpak || exit 1; \
	done
	echo -e "\n-----\nInstalled flatpak packages\n-----\n"
	flatpak list  | grep krosshair

# Runs inside the flatpak-builder sandbox (invoked from the .yml).
# Builds the layer and stages files into the flatpak output (/app).
flatpak-builder-callback: release
	install -Dm755 $(LIBRARY) -t ${FLATPAK_DEST}/lib/
	install -Dm644 krosshair.json -t ${FLATPAK_DEST}/share/vulkan/implicit_layer.d/
	grep -H library_path ${FLATPAK_DEST}/share/vulkan/implicit_layer.d/krosshair.json
