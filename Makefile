.DEFAULT_GOAL := help

XCODEBUILDMCP ?= xcodebuildmcp
WORKSPACE_PATH ?= PersonaKit.xcworkspace
STUDIO_SCHEME ?= PersonaKit
APP_NAME ?= PersonaKit
CONFIGURATION ?= Debug
SWIFT_CONFIGURATION ?= debug
DERIVED_DATA_PATH ?= .build/XcodeDerivedData
ZIP_NAME ?= .build/PersonaKit.zip
INSTALL_BIN_DIR ?= /usr/local/bin
CLI_PRODUCT_NAME ?= personakit
CLI_COMPLETION_SOURCE ?= $(INSTALL_BIN_DIR)/$(CLI_PRODUCT_NAME)
ZSH_COMPLETION_DIR ?= $(HOME)/.zsh/completions
TEST_FILTER ?=
SWIFT ?= swift

# --- macOS installer release lane ----------------------------------------
# Signing identities + the notary keychain profile come from
# Config/Release.local.mk (gitignored). Never commit those values.
RELEASE_LOCAL_CONFIG ?= Config/Release.local.mk
RELEASE_SWIFT_CONFIGURATION ?= release
# NOTE: must not collide (case-insensitively) with SwiftPM's .build/release,
# which the companion CLI build populates; otherwise the archive/export are clobbered.
PKG_BUILD_DIR ?= .build/macos-release
PKG_ARCHIVE_PATH ?= $(PKG_BUILD_DIR)/$(APP_NAME).xcarchive
PKG_EXPORT_PATH ?= $(PKG_BUILD_DIR)/export
PKG_OUTPUT_PATH ?= $(PKG_BUILD_DIR)/$(APP_NAME).pkg
PKG_STAGE_ROOT ?= $(PKG_BUILD_DIR)/pkgroot
PKG_COMPONENT_PLIST ?= $(PKG_BUILD_DIR)/component.plist
PKG_ARCHS ?= arm64 x86_64
PKG_IDENTIFIER ?= com.ajself.PersonaKit
# VERSION is the single knob for cutting a release. It drives the installer
# version, the git tag, the release title, and the version-check expectation.
# It defaults to the version baked into the committed CLI source (the source of
# truth read by version-check), so non-release targets always track the shipped
# version with no hand-editing here. To cut the next release, bump the source
# with `make version-bump VERSION=1.1.0`, commit, then `make studio-publish-release`.
VERSION ?= $(shell sed -n 's/.*static let current = "\([^"]*\)".*/\1/p' "$(CLI_VERSION_FILE)" 2>/dev/null | head -1)
PKG_VERSION ?= $(VERSION)
APP_INSTALL_LOCATION ?= /Applications
CLI_INSTALL_LOCATION ?= /usr/local/bin
CLI_SUPPORT_BUNDLE_NAME ?= PersonaKit_ContextCore.bundle
APP_SIGN_IDENTITY ?=
INSTALLER_SIGN_IDENTITY ?=
NOTARY_KEYCHAIN_PROFILE ?=

# GitHub release publishing. RELEASE_VERSION flows from VERSION (see above) and
# drives the release tag and title. `make version-bump VERSION=x.y.z` keeps the
# two code surfaces in sync so version-check passes:
#   - MARKETING_VERSION in PersonaKit/PersonaKit.xcodeproj (app)
#   - PersonaKitVersion.current in Sources/Features/CLI/PersonaKitVersion.swift (CLI/MCP)
GH ?= gh
RELEASE_VERSION ?= $(PKG_VERSION)
RELEASE_TAG ?= v$(RELEASE_VERSION)
RELEASE_TITLE ?= PersonaKit $(RELEASE_VERSION)
PKG_CHECKSUM_PATH ?= $(PKG_OUTPUT_PATH).sha256

# Version drift guard. `version-check` asserts the code/app version surfaces
# agree with RELEASE_VERSION before the CLI is installed or a release is built.
CLI_VERSION_FILE ?= Sources/Features/CLI/PersonaKitVersion.swift
APP_PROJECT_PBXPROJ ?= PersonaKit/PersonaKit.xcodeproj/project.pbxproj

-include $(RELEASE_LOCAL_CONFIG)

VALIDATE_AGENT ?= local
VALIDATE_USER ?= $(if $(USER),$(USER),unknown)
VALIDATE_TMPDIR ?= /tmp/personakit-$(VALIDATE_USER)-$(VALIDATE_AGENT)
# Keep SwiftPM cache/temp writes out of user caches and the repo tree. This
# lets sandboxed validation run without making scope-discovery tests see the
# checkout's own .personakit while walking upward from temporary directories.
SWIFTPM_CACHE_ROOT ?= $(VALIDATE_TMPDIR)/swiftpm
SWIFTPM_TMPDIR ?= $(SWIFTPM_CACHE_ROOT)/tmp
SWIFTPM_FLAGS ?= --cache-path $(SWIFTPM_CACHE_ROOT)/cache --config-path $(SWIFTPM_CACHE_ROOT)/configuration --security-path $(SWIFTPM_CACHE_ROOT)/security --manifest-cache local --disable-sandbox -Xswiftc -module-cache-path -Xswiftc $(SWIFTPM_CACHE_ROOT)/module-cache -Xcc -fmodules-cache-path=$(SWIFTPM_CACHE_ROOT)/clang-module-cache
PUBLIC_CHECK_TEST ?= 1
# --no-parallel: the swift-testing runner writes per-test progress to stdout, and
# the CLI capture helpers (captureStdout/captureStderr) redirect the process-global
# stdout/stderr fds. Under parallel execution the runner's progress for other tests
# lands in a capture's pipe and corrupts it (intermittent "JSON text did not start
# with array or object"). Serializing the run removes the cross-test fd contention.
# Bonus: it is also faster wall-clock for this suite (no worker-spawn overhead).
SWIFT_TEST_FLAGS ?= --no-parallel
SWIFTPM_ENV ?= CLANG_MODULE_CACHE_PATH=$(SWIFTPM_CACHE_ROOT)/clang-module-cache TMPDIR=$(SWIFTPM_TMPDIR)
SWIFT_BUILD ?= $(SWIFTPM_ENV) $(SWIFT) build $(SWIFTPM_FLAGS)
SWIFT_RUN ?= $(SWIFTPM_ENV) $(SWIFT) run $(SWIFTPM_FLAGS)
SWIFT_TEST ?= $(SWIFTPM_ENV) $(SWIFT) test $(SWIFTPM_FLAGS) $(SWIFT_TEST_FLAGS)

.PHONY: help studio-doctor clean build test format-check swiftpm-prepare \
	core-validate-repo core-zip public-check \
	cli-build cli-install cli-install-zsh-completion cli-test version-check version-bump \
	studio-build studio-run studio-test studio-review \
	studio-pkg-preflight studio-archive-release studio-export-release \
	studio-verify-app studio-pkg-app studio-pkg \
	studio-notarize-pkg studio-staple-pkg studio-verify-pkg studio-release-pkg \
	studio-gh-release studio-publish-release

help:
	@echo "PersonaKit Makefile Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [VAR=value]"
	@echo ""
	@echo "Shared/Core:"
	@printf "  %-28s %s\n" "clean" "Remove SwiftPM build products and Xcode derived data."
	@printf "  %-28s %s\n" "build" "Build the default local CLI surface with SwiftPM."
	@printf "  %-28s %s\n" "test" "Run the package test suite with optional TEST_FILTER."
	@printf "  %-28s %s\n" "format-check" "Lint Sources and Tests with swift-format."
	@printf "  %-28s %s\n" "core-validate-repo" "Run deterministic repo validation."
	@printf "  %-28s %s\n" "core-zip" "Create a project zip archive."
	@printf "  %-28s %s\n" "public-check" "Run public README and starter verification."
	@echo ""
	@echo "CLI surface:"
	@printf "  %-28s %s\n" "cli-build" "Build the SwiftPM CLI executable."
	@printf "  %-28s %s\n" "cli-install" "Install the SwiftPM CLI executable into INSTALL_BIN_DIR."
	@printf "  %-28s %s\n" "cli-install-zsh-completion" "Install zsh completion for the installed personakit CLI."
	@printf "  %-28s %s\n" "cli-test" "Run CLI-focused SwiftPM tests (defaults to filter CLI)."
	@printf "  %-28s %s\n" "version-check" "Assert version surfaces match RELEASE_VERSION (runs before install/release)."
	@printf "  %-28s %s\n" "version-bump" "Set both code version surfaces to VERSION=x.y.z (run before a release)."
	@echo ""
	@echo "Studio app:"
	@printf "  %-28s %s\n" "studio-build" "Build the Studio app target with xcodebuild."
	@printf "  %-28s %s\n" "studio-run" "Build and run the Studio app with XcodeBuildMCP."
	@printf "  %-28s %s\n" "studio-test" "Run Studio Xcode tests only (requires WORKSPACE_PATH)."
	@printf "  %-28s %s\n" "studio-review" "Build Studio and capture review screenshots."
	@echo ""
	@echo "Studio release (signed installer; reads $(RELEASE_LOCAL_CONFIG)):"
	@printf "  %-28s %s\n" "studio-pkg" "Archive, sign, harden-verify, and build the signed .pkg (no notarization)."
	@printf "  %-28s %s\n" "studio-release-pkg" "Full archive -> sign -> package -> notarize -> staple -> verify."
	@printf "  %-28s %s\n" "studio-publish-release" "One shot: studio-release-pkg + checksum + DRAFT a release (set VERSION=x.y.z)."
	@printf "  %-28s %s\n" "studio-gh-release" "Checksum an existing notarized .pkg and DRAFT a GitHub release."

studio-doctor:
	@if ! command -v xcodebuild >/dev/null 2>&1; then \
		echo "error: xcodebuild is required. Install Xcode and Command Line Tools."; \
		echo "hint: xcode-select --install"; \
		exit 1; \
	fi
	@if [ ! -d "$(WORKSPACE_PATH)" ]; then \
		echo "error: workspace not found at $(WORKSPACE_PATH)"; \
		exit 1; \
	fi
	@if ! command -v $(XCODEBUILDMCP) >/dev/null 2>&1; then \
		echo "error: $(XCODEBUILDMCP) is required for Studio Xcode targets."; \
		exit 1; \
	fi
	@echo "studio-doctor: OK"

clean:
	@echo "Removing SwiftPM build products..."
	@$(SWIFT) package clean
	@echo "Removing Xcode derived data..."
	@rm -rf "$(DERIVED_DATA_PATH)"
	@echo "clean: OK"

build: cli-build

swiftpm-prepare:
	@mkdir -p "$(SWIFTPM_CACHE_ROOT)/cache" \
		"$(SWIFTPM_CACHE_ROOT)/clang-module-cache" \
		"$(SWIFTPM_CACHE_ROOT)/configuration" \
		"$(SWIFTPM_CACHE_ROOT)/module-cache" \
		"$(SWIFTPM_CACHE_ROOT)/security" \
		"$(SWIFTPM_TMPDIR)"

format-check:
	swift format lint --strict -r Sources Tests

studio-build: studio-doctor
	xcodebuild \
		-workspace "$(WORKSPACE_PATH)" \
		-scheme "$(STUDIO_SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		build

cli-build: swiftpm-prepare
	$(SWIFT_BUILD) -c $(SWIFT_CONFIGURATION) --product $(CLI_PRODUCT_NAME)

# Rewrite the two code version surfaces to VERSION so a release can be cut with
# one knob. Run `make version-bump VERSION=1.1.0`, review the diff, commit, then
# `make studio-publish-release VERSION=1.1.0`. Sets MARKETING_VERSION to the
# major.minor (the Apple convention this project uses) and the CLI to the full
# semver; version-check accepts both.
version-bump:
	@if [ "$(origin VERSION)" = "file" ] || [ "$(origin VERSION)" = "default" ]; then \
		echo "version-bump: VERSION is required (it defaults to the current $(VERSION))."; \
		echo "usage: make version-bump VERSION=1.1.0"; \
		exit 1; \
	fi
	@case "$(VERSION)" in \
		*.*.*) ;; \
		*) echo "version-bump: VERSION must be semver x.y.z (got '$(VERSION)')"; \
			echo "usage: make version-bump VERSION=1.1.0"; exit 1;; \
	esac
	@printf '%s' "$(VERSION)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { \
		echo "version-bump: VERSION must be semver x.y.z (got '$(VERSION)')"; \
		exit 1; \
	}
	@if [ ! -f "$(CLI_VERSION_FILE)" ]; then \
		echo "version-bump: $(CLI_VERSION_FILE) not found"; exit 1; \
	fi
	@if [ ! -f "$(APP_PROJECT_PBXPROJ)" ]; then \
		echo "version-bump: $(APP_PROJECT_PBXPROJ) not found"; exit 1; \
	fi
	@rel_mm="$$(printf '%s' "$(VERSION)" | cut -d. -f1-2)"; \
	sed -i '' 's/static let current = "[^"]*"/static let current = "$(VERSION)"/' "$(CLI_VERSION_FILE)"; \
	sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $$rel_mm;/" "$(APP_PROJECT_PBXPROJ)"; \
	echo "version-bump: set CLI current=$(VERSION), MARKETING_VERSION=$$rel_mm"
	@$(MAKE) --no-print-directory version-check VERSION=$(VERSION)
	@echo "version-bump: review the diff and commit, then run 'make studio-publish-release VERSION=$(VERSION)'."

# Fail fast if the CLI/app version surfaces have drifted from RELEASE_VERSION.
# Guards against shipping a binary whose --version lies (the stale-install
# failure mode). Keep PersonaKitVersion.current and MARKETING_VERSION in sync
# with RELEASE_VERSION (see the version block above).
version-check:
	@cli_ver="$$(sed -n 's/.*static let current = "\([^"]*\)".*/\1/p' "$(CLI_VERSION_FILE)" | head -1)"; \
	if [ -z "$$cli_ver" ]; then \
		echo "version-check: could not read PersonaKitVersion.current from $(CLI_VERSION_FILE)"; \
		exit 1; \
	fi; \
	if [ "$$cli_ver" != "$(RELEASE_VERSION)" ]; then \
		echo "version-check: drift detected"; \
		echo "  PersonaKitVersion.current = $$cli_ver"; \
		echo "  RELEASE_VERSION           = $(RELEASE_VERSION)"; \
		echo "  fix: set 'static let current = \"$(RELEASE_VERSION)\"' in $(CLI_VERSION_FILE)"; \
		exit 1; \
	fi; \
	rel_mm="$$(printf '%s' "$(RELEASE_VERSION)" | cut -d. -f1-2)"; \
	if [ -f "$(APP_PROJECT_PBXPROJ)" ]; then \
		for mkt in $$(sed -n 's/.*MARKETING_VERSION = \([0-9.]*\);.*/\1/p' "$(APP_PROJECT_PBXPROJ)" | sort -u); do \
			if [ "$$mkt" != "$(RELEASE_VERSION)" ] && [ "$$mkt" != "$$rel_mm" ]; then \
				echo "version-check: drift detected"; \
				echo "  MARKETING_VERSION = $$mkt"; \
				echo "  RELEASE_VERSION   = $(RELEASE_VERSION)"; \
				echo "  fix: set MARKETING_VERSION to $$rel_mm (or $(RELEASE_VERSION)) in $(APP_PROJECT_PBXPROJ)"; \
				exit 1; \
			fi; \
		done; \
	fi; \
	echo "version-check: OK ($(RELEASE_VERSION))"

cli-install: version-check cli-build
	@bin_dir="$$($(SWIFT_BUILD) -c $(SWIFT_CONFIGURATION) --show-bin-path)"; \
	install -d "$(INSTALL_BIN_DIR)"; \
	install -m 755 "$$bin_dir/$(CLI_PRODUCT_NAME)" "$(INSTALL_BIN_DIR)/$(CLI_PRODUCT_NAME)"; \
	for bundle in "$$bin_dir"/*.bundle; do \
		[ -d "$$bundle" ] || continue; \
		bundle_name="$$(basename "$$bundle")"; \
		rm -rf "$(INSTALL_BIN_DIR)/$$bundle_name"; \
		ditto "$$bundle" "$(INSTALL_BIN_DIR)/$$bundle_name"; \
	done; \
	installed="$(INSTALL_BIN_DIR)/$(CLI_PRODUCT_NAME)"; \
	resolved="$$(command -v $(CLI_PRODUCT_NAME) 2>/dev/null || true)"; \
	if [ -z "$$resolved" ]; then \
		echo "cli-install: warning: $(CLI_PRODUCT_NAME) is not on PATH; add $(INSTALL_BIN_DIR) to PATH."; \
	elif [ "$$resolved" != "$$installed" ]; then \
		echo "cli-install: warning: PATH resolves $(CLI_PRODUCT_NAME) to $$resolved,"; \
		echo "  not the just-installed $$installed — a copy earlier on PATH is shadowing this install."; \
	else \
		ver="$$("$$resolved" --version 2>/dev/null || true)"; \
		if [ "$$ver" != "$(RELEASE_VERSION)" ]; then \
			echo "cli-install: warning: $$resolved reports version '$$ver', expected $(RELEASE_VERSION)."; \
		else \
			echo "cli-install: OK ($$resolved -> $$ver)"; \
		fi; \
	fi

cli-install-zsh-completion:
	@if [ ! -x "$(CLI_COMPLETION_SOURCE)" ]; then \
		echo "error: completion source not found or not executable: $(CLI_COMPLETION_SOURCE)"; \
		echo "hint: run 'make cli-install' first or set CLI_COMPLETION_SOURCE=/path/to/personakit"; \
		exit 1; \
	fi
	install -d "$(ZSH_COMPLETION_DIR)"
	"$(CLI_COMPLETION_SOURCE)" --generate-completion-script zsh > "$(ZSH_COMPLETION_DIR)/_$(CLI_PRODUCT_NAME)"
	@echo "Installed zsh completion to $(ZSH_COMPLETION_DIR)/_$(CLI_PRODUCT_NAME)"
	@echo "If needed, add this to ~/.zshrc:"
	@echo "  fpath=($(ZSH_COMPLETION_DIR) \$$fpath)"
	@echo "  autoload -Uz compinit"
	@echo "  compinit"

studio-run: studio-doctor
	@echo "Stopping existing $(APP_NAME) instances via XcodeBuildMCP..."
	@$(XCODEBUILDMCP) macos stop --app-name "$(APP_NAME)" >/dev/null 2>&1 || true
	$(XCODEBUILDMCP) macos build-and-run \
		--workspace-path "$(WORKSPACE_PATH)" \
		--scheme "$(STUDIO_SCHEME)" \
		--configuration "$(CONFIGURATION)" \
		--derived-data-path "$(DERIVED_DATA_PATH)"

studio-review:
	bash Scripts/studio-review.sh

test: swiftpm-prepare
	$(SWIFT_TEST) $(if $(TEST_FILTER),--filter "$(TEST_FILTER)",)

studio-test: studio-doctor
	@$(XCODEBUILDMCP) macos stop --app-name "$(APP_NAME)" >/dev/null 2>&1 || true
	xcodebuild \
		-workspace "$(WORKSPACE_PATH)" \
		-scheme "$(STUDIO_SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-derivedDataPath "$(DERIVED_DATA_PATH)" \
		test

cli-test: swiftpm-prepare
	$(SWIFT_TEST) --filter "$(if $(TEST_FILTER),$(TEST_FILTER),CLI)"

core-validate-repo: swiftpm-prepare
	PERSONAKIT_VALIDATE_TMP_ROOT=$(VALIDATE_TMPDIR) ./Scripts/validate-repo.sh

public-check: swiftpm-prepare
ifeq ($(PUBLIC_CHECK_TEST),1)
	$(SWIFT_TEST)
endif
	$(SWIFT_RUN) personakit --help
	$(SWIFT_RUN) personakit export --help
	rm -rf /tmp/personakit-public-check
	mkdir -p /tmp/personakit-public-check
	! find .personakit Examples/public-starter/.personakit \( -name .DS_Store -o -name '._*' \) -print | grep .
# Compare file content, not directory structure: git diff --no-index ignores
# empty dirs (git cannot track them), so a stray empty dir left by tooling does
# not spuriously fail the mirror check. Plain diff -qr fails on such a dir.
	git diff --no-index .personakit Examples/public-starter/.personakit
	$(SWIFT_RUN) personakit validate --root .personakit
	$(SWIFT_RUN) personakit validate --root Fixtures/internal-agent-root/.personakit
	$(SWIFT_RUN) personakit validate --root Fixtures/kit-root
	$(SWIFT_RUN) personakit validate --root Examples/public-starter/.personakit
	$(SWIFT_RUN) personakit contract --root Examples/public-starter/.personakit --session solo-dev > /tmp/personakit-public-check/example-contract.json
	grep -F '"sessionId" : "solo-dev"' /tmp/personakit-public-check/example-contract.json
	grep -F '"authorizedSkillIds" : [' /tmp/personakit-public-check/example-contract.json
	$(SWIFT_RUN) personakit export --root Examples/public-starter/.personakit --session solo-dev > /tmp/personakit-public-check/example-export.md
	grep -F 'PersonaKit-Output-Version: 1' /tmp/personakit-public-check/example-export.md
	grep -F '# Persona' /tmp/personakit-public-check/example-export.md
	grep -F '# Skill Contract' /tmp/personakit-public-check/example-export.md
	grep -F '# Directive' /tmp/personakit-public-check/example-export.md
	$(SWIFT_RUN) personakit init /tmp/personakit-public-check/.personakit
	$(SWIFT_RUN) personakit validate --root /tmp/personakit-public-check/.personakit
	$(SWIFT_RUN) personakit export --root /tmp/personakit-public-check/.personakit --session solo-dev > /tmp/personakit-public-check/init-export.md
	grep -F 'PersonaKit-Output-Version: 1' /tmp/personakit-public-check/init-export.md
	grep -F '# Persona' /tmp/personakit-public-check/init-export.md
	grep -F '# Skill Contract' /tmp/personakit-public-check/init-export.md
	grep -F '# Directive' /tmp/personakit-public-check/init-export.md
	mkdir -p /tmp/personakit-public-check/non-empty
	printf "occupied\n" > /tmp/personakit-public-check/non-empty/README.md
	! $(SWIFT_RUN) personakit init /tmp/personakit-public-check/non-empty
	$(SWIFT_RUN) personakit init /tmp/personakit-public-check/non-empty --force
	$(SWIFT_RUN) personakit validate --root /tmp/personakit-public-check/non-empty
	! grep -REn "A[J]|O[r]bit|T[ask]board|architectural-editor|Studio release|workflow platform" .personakit README.md Docs Examples AGENTS.md
	grep -REn "memory|orchestration" .personakit README.md Docs Examples AGENTS.md || true

core-zip:
	@mkdir -p "$(dir $(ZIP_NAME))"
	@rm -f "$(ZIP_NAME)"
	git ls-files -z | xargs -0 zip -q "$(ZIP_NAME)"

# --- macOS installer release lane -----------------------------------------
# Release targets build the Release configuration regardless of the default.
studio-archive-release studio-export-release studio-verify-app studio-pkg-app studio-pkg studio-notarize-pkg studio-staple-pkg studio-verify-pkg studio-release-pkg: CONFIGURATION = Release

studio-pkg-preflight: version-check
	@if ! command -v xcodebuild >/dev/null 2>&1; then \
		echo "error: xcodebuild is required. Install Xcode and Command Line Tools."; \
		exit 1; \
	fi
	@if [ ! -d "$(WORKSPACE_PATH)" ]; then \
		echo "error: workspace not found at $(WORKSPACE_PATH)"; \
		exit 1; \
	fi
	@if ! command -v pkgbuild >/dev/null 2>&1; then \
		echo "error: pkgbuild is required."; \
		exit 1; \
	fi
	@if ! command -v $(SWIFT) >/dev/null 2>&1; then \
		echo "error: $(SWIFT) is required to build the companion CLI."; \
		exit 1; \
	fi
	@if ! xcrun --find notarytool >/dev/null 2>&1; then \
		echo "error: notarytool is required via xcrun."; \
		exit 1; \
	fi
	@if ! xcrun --find stapler >/dev/null 2>&1; then \
		echo "error: stapler is required via xcrun."; \
		exit 1; \
	fi
	@if [ -z "$(APP_SIGN_IDENTITY)" ]; then \
		echo "error: APP_SIGN_IDENTITY is required (set it in $(RELEASE_LOCAL_CONFIG))."; \
		exit 1; \
	fi
	@echo "studio-pkg-preflight: OK"

studio-archive-release: studio-pkg-preflight
	@mkdir -p "$(dir $(PKG_ARCHIVE_PATH))"
	xcodebuild archive \
		-workspace "$(WORKSPACE_PATH)" \
		-scheme "$(STUDIO_SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "generic/platform=macOS" \
		-archivePath "$(PKG_ARCHIVE_PATH)" \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="$(APP_SIGN_IDENTITY)" \
		OTHER_CODE_SIGN_FLAGS="--timestamp" \
		ONLY_ACTIVE_ARCH=NO \
		ARCHS="$(PKG_ARCHS)"

studio-export-release:
	@if [ ! -d "$(PKG_ARCHIVE_PATH)" ]; then \
		echo "error: archive not found at $(PKG_ARCHIVE_PATH)"; \
		echo "hint: run 'make studio-archive-release' first"; \
		exit 1; \
	fi
	@if [ ! -d "$(PKG_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app" ]; then \
		echo "error: archived app not found in $(PKG_ARCHIVE_PATH)/Products/Applications"; \
		exit 1; \
	fi
	@mkdir -p "$(PKG_BUILD_DIR)"
	@rm -rf "$(PKG_EXPORT_PATH)"
	@mkdir -p "$(PKG_EXPORT_PATH)"
	@ditto --norsrc --noqtn "$(PKG_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app" "$(PKG_EXPORT_PATH)/$(APP_NAME).app"
	@if [ ! -d "$(PKG_EXPORT_PATH)/$(APP_NAME).app" ]; then \
		echo "error: exported app not found at $(PKG_EXPORT_PATH)/$(APP_NAME).app"; \
		exit 1; \
	fi

# Harden gate: hardened runtime, secure timestamp, and the exact distribution
# entitlement set the global-library grant needs. bookmarks.app-scope must stay
# ABSENT on purpose: the security-scoped bookmark resolves across relaunches
# without it, and asserting its absence keeps the signing surface from drifting.
studio-verify-app:
	@set -e; \
	app="$(PKG_EXPORT_PATH)/$(APP_NAME).app"; \
	if [ ! -d "$$app" ]; then \
		echo "error: exported app not found at $$app"; \
		echo "hint: run 'make studio-export-release' first"; \
		exit 1; \
	fi; \
	details="$$(codesign -dvv "$$app" 2>&1)"; \
	if ! printf '%s' "$$details" | grep -qi 'flags=[^ ]*runtime'; then \
		echo "error: $$app is not signed with the hardened runtime."; \
		exit 1; \
	fi; \
	if ! printf '%s' "$$details" | grep -q 'Timestamp='; then \
		echo "error: $$app does not carry a secure timestamp."; \
		exit 1; \
	fi; \
	ents="$$(codesign -d --entitlements :- "$$app" 2>/dev/null || true)"; \
	norm="$$(printf '%s' "$$ents" | tr -d ' \t\n\r')"; \
	if ! printf '%s' "$$norm" | grep -q '<key>com.apple.security.app-sandbox</key><true/>'; then \
		echo "error: $$app is not sandboxed (com.apple.security.app-sandbox must be true)."; \
		exit 1; \
	fi; \
	if ! printf '%s' "$$norm" | grep -q '<key>com.apple.security.files.user-selected.read-write</key><true/>'; then \
		echo "error: $$app is missing com.apple.security.files.user-selected.read-write; the global-library grant would break."; \
		exit 1; \
	fi; \
	if printf '%s' "$$norm" | grep -q '<key>com.apple.security.get-task-allow</key><true/>'; then \
		echo "error: $$app ships com.apple.security.get-task-allow=true; not a distribution build."; \
		exit 1; \
	fi; \
	if printf '%s' "$$norm" | grep -q 'com.apple.security.files.bookmarks.app-scope'; then \
		echo "error: $$app declares com.apple.security.files.bookmarks.app-scope; S4 requires it stay absent (security-scoped bookmarks resolve without it)."; \
		exit 1; \
	fi; \
	echo "studio-verify-app: hardened runtime + secure timestamp OK; sandbox on, user-selected read-write present, no get-task-allow, no app-scope bookmarks."

studio-pkg-app:
	@if [ ! -d "$(PKG_EXPORT_PATH)/$(APP_NAME).app" ]; then \
		echo "error: exported app not found at $(PKG_EXPORT_PATH)/$(APP_NAME).app"; \
		echo "hint: run 'make studio-export-release' first"; \
		exit 1; \
	fi
	@if [ -z "$(INSTALLER_SIGN_IDENTITY)" ]; then \
		echo "error: INSTALLER_SIGN_IDENTITY is required (set it in $(RELEASE_LOCAL_CONFIG))."; \
		exit 1; \
	fi
	@if [ -z "$(APP_SIGN_IDENTITY)" ]; then \
		echo "error: APP_SIGN_IDENTITY is required (set it in $(RELEASE_LOCAL_CONFIG))."; \
		exit 1; \
	fi
	@echo "Building companion CLI ($(CLI_PRODUCT_NAME)) for release..."
	$(SWIFT) build -c $(RELEASE_SWIFT_CONFIGURATION) --product $(CLI_PRODUCT_NAME)
	@mkdir -p "$(dir $(PKG_OUTPUT_PATH))"
	@rm -rf "$(PKG_STAGE_ROOT)"
	@mkdir -p "$(PKG_STAGE_ROOT)$(APP_INSTALL_LOCATION)"
	@mkdir -p "$(PKG_STAGE_ROOT)$(CLI_INSTALL_LOCATION)"
	@ditto --norsrc --noqtn "$(PKG_EXPORT_PATH)/$(APP_NAME).app" "$(PKG_STAGE_ROOT)$(APP_INSTALL_LOCATION)/$(APP_NAME).app"
	@set -e; \
	bin_dir="$$($(SWIFT) build -c $(RELEASE_SWIFT_CONFIGURATION) --product $(CLI_PRODUCT_NAME) --show-bin-path)"; \
	cli="$$bin_dir/$(CLI_PRODUCT_NAME)"; \
	bundle="$$bin_dir/$(CLI_SUPPORT_BUNDLE_NAME)"; \
	if [ ! -x "$$cli" ]; then echo "error: built CLI not found at $$cli"; exit 1; fi; \
	codesign --force --options runtime --timestamp --sign "$(APP_SIGN_IDENTITY)" "$$cli"; \
	codesign --verify --strict "$$cli"; \
	if ! codesign -dvv "$$cli" 2>&1 | grep -qi 'flags=[^ ]*runtime'; then \
		echo "error: companion CLI is not signed with the hardened runtime."; \
		exit 1; \
	fi; \
	ditto --norsrc --noqtn "$$cli" "$(PKG_STAGE_ROOT)$(CLI_INSTALL_LOCATION)/$(CLI_PRODUCT_NAME)"; \
	if [ -d "$$bundle" ]; then \
		ditto --norsrc --noqtn "$$bundle" "$(PKG_STAGE_ROOT)$(CLI_INSTALL_LOCATION)/$(CLI_SUPPORT_BUNDLE_NAME)"; \
	else \
		echo "warning: resource bundle $(CLI_SUPPORT_BUNDLE_NAME) not found at $$bundle; skipping"; \
	fi
	@xattr -cr "$(PKG_STAGE_ROOT)"
	@find "$(PKG_STAGE_ROOT)" -name '._*' -delete
	@pkgbuild --analyze --root "$(PKG_STAGE_ROOT)" "$(PKG_COMPONENT_PLIST)"
	@set -e; \
	i=0; \
	while /usr/libexec/PlistBuddy -c "Print :$$i:BundleIsRelocatable" "$(PKG_COMPONENT_PLIST)" >/dev/null 2>&1; do \
		/usr/libexec/PlistBuddy -c "Set :$$i:BundleIsRelocatable false" "$(PKG_COMPONENT_PLIST)"; \
		/usr/libexec/PlistBuddy -c "Set :$$i:BundleHasStrictIdentifier true" "$(PKG_COMPONENT_PLIST)"; \
		/usr/libexec/PlistBuddy -c "Set :$$i:BundleOverwriteAction upgrade" "$(PKG_COMPONENT_PLIST)"; \
		i=$$((i + 1)); \
	done; \
	echo "studio-pkg-app: configured $$i bundle component(s) as non-relocatable."
	@rm -f "$(PKG_OUTPUT_PATH)"
	pkgbuild \
		--root "$(PKG_STAGE_ROOT)" \
		--identifier "$(PKG_IDENTIFIER)" \
		--version "$(PKG_VERSION)" \
		--install-location "/" \
		--component-plist "$(PKG_COMPONENT_PLIST)" \
		--sign "$(INSTALLER_SIGN_IDENTITY)" \
		--timestamp \
		"$(PKG_OUTPUT_PATH)"
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		exit 1; \
	fi
	@echo "studio-pkg-app: built $(PKG_OUTPUT_PATH)"

# Build + sign + package without contacting Apple. Produces a signed but
# un-notarized .pkg, handy for local install testing.
studio-pkg: studio-pkg-preflight studio-archive-release studio-export-release studio-verify-app studio-pkg-app
	@echo "studio-pkg: signed installer ready at $(PKG_OUTPUT_PATH) (not yet notarized)."

studio-notarize-pkg:
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		echo "hint: run 'make studio-pkg' first"; \
		exit 1; \
	fi
	@if [ -z "$(NOTARY_KEYCHAIN_PROFILE)" ]; then \
		echo "error: NOTARY_KEYCHAIN_PROFILE is required (set it in $(RELEASE_LOCAL_CONFIG))."; \
		echo "hint: create it once with 'xcrun notarytool store-credentials'"; \
		exit 1; \
	fi
	xcrun notarytool submit "$(PKG_OUTPUT_PATH)" \
		--keychain-profile "$(NOTARY_KEYCHAIN_PROFILE)" \
		--wait

studio-staple-pkg:
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		exit 1; \
	fi
	xcrun stapler staple "$(PKG_OUTPUT_PATH)"

studio-verify-pkg:
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		exit 1; \
	fi
	pkgutil --check-signature "$(PKG_OUTPUT_PATH)"
	xcrun stapler validate "$(PKG_OUTPUT_PATH)"
	spctl -a -t install -vv "$(PKG_OUTPUT_PATH)"
	@echo "studio-verify-pkg: signature and stapling look good."

studio-release-pkg: studio-pkg-preflight studio-archive-release studio-export-release studio-verify-app studio-pkg-app studio-notarize-pkg studio-staple-pkg studio-verify-pkg
	@echo "studio-release-pkg: notarized installer ready at $(PKG_OUTPUT_PATH)."

# Checksum a notarized .pkg and DRAFT a GitHub release for it. Always a draft:
# nothing goes public (and no tag is pushed) until you publish it on GitHub.
studio-gh-release:
	@command -v $(GH) >/dev/null 2>&1 || { \
		echo "error: GitHub CLI ($(GH)) is required (brew install gh)."; \
		exit 1; \
	}
	@$(GH) auth status >/dev/null 2>&1 || { \
		echo "error: GitHub CLI is not authenticated; run '$(GH) auth login' first."; \
		exit 1; \
	}
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		echo "hint: run 'make studio-release-pkg' first"; \
		exit 1; \
	fi
	@xcrun stapler validate "$(PKG_OUTPUT_PATH)" >/dev/null 2>&1 || { \
		echo "error: $(PKG_OUTPUT_PATH) is not notarized/stapled; run 'make studio-release-pkg' first."; \
		exit 1; \
	}
	@published="$$($(GH) release list --limit 100 --json tagName,isDraft \
		--jq 'map(select(.tagName == "$(RELEASE_TAG)" and .isDraft == false)) | length')"; \
	if [ "$$published" != "0" ]; then \
		echo "error: a published release already exists for $(RELEASE_TAG)."; \
		echo "hint: bump the version first, e.g. 'make version-bump VERSION=1.1.0',"; \
		echo "      commit, then re-run with VERSION=1.1.0."; \
		exit 1; \
	fi; \
	draft="$$($(GH) release list --limit 100 --json tagName,isDraft \
		--jq 'map(select(.tagName == "$(RELEASE_TAG)" and .isDraft == true)) | length')"; \
	if [ "$$draft" != "0" ]; then \
		echo "error: a draft release already exists for $(RELEASE_TAG); drafting again would duplicate it."; \
		echo "hint: delete the old draft first ('gh release list' to find it), then re-run."; \
		exit 1; \
	fi
	@cd "$(dir $(PKG_OUTPUT_PATH))" && shasum -a 256 "$(notdir $(PKG_OUTPUT_PATH))" > "$(notdir $(PKG_CHECKSUM_PATH))"
	@echo "Drafting GitHub release $(RELEASE_TAG) (DRAFT only; nothing published)..."
	@$(GH) release create "$(RELEASE_TAG)" \
		"$(PKG_OUTPUT_PATH)" "$(PKG_CHECKSUM_PATH)" \
		--draft \
		--title "$(RELEASE_TITLE)" \
		--generate-notes
	@echo "studio-gh-release: draft $(RELEASE_TAG) created. Review and publish it on GitHub."

# One shot: build + notarize, then draft a GitHub release with the .pkg + checksum.
studio-publish-release: studio-release-pkg studio-gh-release
	@echo "studio-publish-release: draft $(RELEASE_TAG) ready for review (nothing published yet)."
