LIBRARY = lib/krosshair.so

CCFLAGS = -Wall -std=c99 -fPIC -shared -I./include/
LDFLAGS = -ldl -lm

# Version comes from git unless KROSSHAIR_VERSION is set (release builds set it explicitly):
#   v0.5.0 checked out              -> 0.5.0
#   8 commits past v0.5.0           -> 0.5.0+8.g0587d41
#   uncommitted changes to tracked  -> 0.5.0+dirty, or 0.5.0+8.g0587d41.dirty
ifeq ($(KROSSHAIR_VERSION),)
KROSSHAIR_VERSION := $(shell \
	d=$$(git describe --tags --long --match 'v[0-9]*' 2>/dev/null); \
	if [ -n "$$d" ]; then \
		v=$$(echo "$$d" | sed -E 's/^v//; s/-0-g[0-9a-f]+$$//; s/-([0-9]+)-g([0-9a-f]+)$$/+\1.g\2/'); \
	else \
		h=$$(git rev-parse --short HEAD 2>/dev/null); \
		v=$${h:+0.0.0+g$$h}; v=$${v:-0.0.0}; \
	fi; \
	if [ -n "$$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; then \
		if echo "$$v" | grep -q '+'; then v="$$v.dirty"; else v="$$v+dirty"; fi; \
	fi; \
	echo "$$v")
endif

CCFLAGS += -DKROSSHAIR_VERSION=\"$(KROSSHAIR_VERSION)\"

# Debug build by default; use `make release` or `make RELEASE=1` for release
ifdef RELEASE
CCFLAGS += -O2 -DNDEBUG
else
CCFLAGS += -ggdb
endif

SOURCES = $(shell find src -type f -name "*.c")

.PHONY: all release clean install version

all:
	mkdir -p lib
	$(CC) $(CCFLAGS) $(SOURCES) $(LDFLAGS) -o $(LIBRARY)

release:
	$(MAKE) RELEASE=1 all

install:
	sudo mkdir -p /usr/lib/krosshair
	sudo cp $(LIBRARY) /usr/lib/krosshair/krosshair.so
	sudo cp krosshair.json /usr/share/vulkan/implicit_layer.d/krosshair.json

version:
	@echo $(KROSSHAIR_VERSION)

clean:
	rm -f $(LIBRARY)
