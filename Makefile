# Egakium convenience targets.

.PHONY: app version test build clean release install uninstall

# Where to link the `egakium` command. /usr/local/bin is on the default macOS
# PATH. For a no-sudo install use:  make install BINDIR=$(HOME)/.local/bin
BINDIR ?= /usr/local/bin

# Generate the Xcode project and open it (apps build/run from Xcode).
app:
	xcodegen generate
	scripts/check-version-consistency.sh
	open Egakium.xcodeproj

version:
	scripts/check-version-consistency.sh

# Library/logic layer: build + run the XCTest suites (no Xcode needed).
test: version
	swift test

build: version
	swift build

clean:
	rm -rf .build Egakium.xcodeproj

# Optimized standalone binary at .build/release/egakium (no sudo).
release: version
	swift build -c release

# Symlink that binary into your PATH so `egakium` works from any directory.
# Run `make release` first; afterwards every `make release` is instantly live
# (no reinstall). Use sudo if BINDIR isn't writable: `sudo make install`.
install:
	@test -x "$(CURDIR)/.build/release/egakium" || { echo "run 'make release' first"; exit 1; }
	@mkdir -p "$(BINDIR)"
	ln -sf "$(CURDIR)/.build/release/egakium" "$(BINDIR)/egakium"
	@echo "linked $(BINDIR)/egakium -> $(CURDIR)/.build/release/egakium"

uninstall:
	rm -f "$(BINDIR)/egakium"
