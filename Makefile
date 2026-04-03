.DEFAULT_GOAL := help

XCODEBUILDMCP ?= xcodebuildmcp
WORKSPACE_PATH ?= PersonaKit.xcworkspace
RUN_SCHEME ?= PersonaKit
APP_NAME ?= PersonaKit
APP_BUILD_SCHEME ?= PersonaKitStudio
CLI_BUILD_SCHEME ?= PersonaKitCLI
CONFIGURATION ?= Debug
SWIFT_CONFIGURATION ?= debug
DERIVED_DATA_PATH ?= .build/XcodeDerivedData
ZIP_NAME ?= PersonaKit.zip
INSTALL_BIN_DIR ?= /usr/local/bin
CLI_PRODUCT_NAME ?= personakit
CLI_COMPLETION_SOURCE ?= $(INSTALL_BIN_DIR)/$(CLI_PRODUCT_NAME)
ZSH_COMPLETION_DIR ?= $(HOME)/.zsh/completions
RELEASE_LOCAL_CONFIG ?= Config/Release.local.mk
PKG_BUILD_DIR ?= .build/Release
PKG_ARCHIVE_PATH ?= $(PKG_BUILD_DIR)/$(APP_NAME).xcarchive
PKG_EXPORT_PATH ?= $(PKG_BUILD_DIR)/export
PKG_OUTPUT_PATH ?= $(PKG_BUILD_DIR)/$(APP_NAME).pkg
PKG_STAGE_ROOT ?= $(PKG_BUILD_DIR)/pkgroot
PKG_COMPONENT_PLIST ?= $(PKG_BUILD_DIR)/component.plist
PKG_EXPORT_OPTIONS_PLIST ?= Config/ExportOptions-DeveloperID.plist
PKG_ARCHS ?= arm64 x86_64
PKG_IDENTIFIER ?= com.ajself.PersonaKit
PKG_VERSION ?= 1.0.0
APP_INSTALL_LOCATION ?= /Applications
INSTALLER_SIGN_IDENTITY ?=
NOTARY_KEYCHAIN_PROFILE ?=
TEST_FILTER ?=

-include $(RELEASE_LOCAL_CONFIG)

ROOT ?=
SESSION ?= architectural-editor-review
OUTPUT ?= /tmp/session.md
TYPE ?=
ARGS ?=
NO_PROJECT ?= 0
NO_GLOBAL ?= 0

VALIDATE_AGENT ?= local
VALIDATE_USER ?= $(if $(USER),$(USER),unknown)
VALIDATE_TMPDIR ?= /tmp/personakit-$(VALIDATE_USER)-$(VALIDATE_AGENT)

COMPLETE_WORKTREE_BRANCH ?=
COMPLETE_WORKTREE_PATH ?=
COMPLETE_WORKTREE_MAIN ?= main
COMPLETE_WORKTREE_NO_CLEANUP ?= 0

ROOT_ARG := $(if $(ROOT),--root $(ROOT),)
SCOPE_ARGS := $(ROOT_ARG) $(if $(filter 1 true yes,$(NO_PROJECT)),--no-project,) $(if $(filter 1 true yes,$(NO_GLOBAL)),--no-global,)

.PHONY: help doctor build build-app build-cli install-cli install-zsh-completion run test test-cli cli init validate validate-repo complete-worktree export list graph zip format-check pkg-preflight archive-app-release export-app-release pkg-app notarize-pkg staple-pkg verify-pkg release-pkg

archive-app-release export-app-release pkg-app notarize-pkg staple-pkg verify-pkg release-pkg: CONFIGURATION = Release

help:
	@echo "PersonaKit Makefile Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [VAR=value]"
	@echo ""
	@echo "Tasks:"
	@printf "  %-24s %s\n" "doctor" "Check required tools and workspace health."
	@printf "  %-24s %s\n" "build" "Build macOS app and CLI with XcodeBuildMCP."
	@printf "  %-24s %s\n" "build-app" "Build macOS app scheme with XcodeBuildMCP."
	@printf "  %-24s %s\n" "build-cli" "Build CLI scheme with XcodeBuildMCP."
	@printf "  %-24s %s\n" "install-cli" "Build the Swift CLI and install it into INSTALL_BIN_DIR."
	@printf "  %-24s %s\n" "install-zsh-completion" "Install zsh completion for the installed personakit CLI."
	@printf "  %-24s %s\n" "run" "Build and run macOS app with XcodeBuildMCP."
	@printf "  %-24s %s\n" "test" "Run SwiftPM tests and default Xcode host/UI smoke checks."
	@printf "  %-24s %s\n" "test-cli" "Run CLI-focused SwiftPM tests (defaults to filter \`CLI\`)."
	@printf "  %-24s %s\n" "pkg-preflight" "Check macOS packaging tools, export options, and release inputs."
	@printf "  %-24s %s\n" "archive-app-release" "Archive the host app for Release distribution."
	@printf "  %-24s %s\n" "export-app-release" "Export the archived host app for Developer ID distribution."
	@printf "  %-24s %s\n" "pkg-app" "Create a signed installer package for the exported app."
	@printf "  %-24s %s\n" "notarize-pkg" "Submit the installer package for notarization."
	@printf "  %-24s %s\n" "staple-pkg" "Staple the notarization ticket to the installer package."
	@printf "  %-24s %s\n" "verify-pkg" "Verify installer signing and stapled notarization."
	@printf "  %-24s %s\n" "release-pkg" "Run the full archive, export, package, notarize, staple, verify flow."
	@printf "  %-24s %s\n" "zip" "Create a project zip archive."
	@echo ""
	@echo "PersonaKit workflow tasks:"
	@printf "  %-24s %s\n" "cli" "Run the personakit CLI directly."
	@printf "  %-24s %s\n" "init" "Initialize a starter kit in ./.personakit."
	@printf "  %-24s %s\n" "validate" "Validate using scope discovery or ROOT override."
	@printf "  %-24s %s\n" "validate-repo" "Run deterministic repo validation."
	@printf "  %-24s %s\n" "complete-worktree" "Rebase & ff-merge feature branch to main, delete worktree & branch (--no-cleanup preserves worktree/branch)"
	@printf "  %-24s %s\n" "export" "Export a resolved PersonaKit session prompt."
	@printf "  %-24s %s\n" "list" "List PersonaKit entities (requires TYPE)."
	@printf "  %-24s %s\n" "graph" "Render session dependency graph."

doctor:
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
		echo "xcodebuildmcp not found. Installing via Homebrew..."; \
		if ! command -v brew >/dev/null 2>&1; then \
			echo "error: Homebrew is required to install xcodebuildmcp."; \
			echo "hint: https://brew.sh"; \
			exit 1; \
		fi; \
		brew tap getsentry/tools; \
		brew install getsentry/tools/xcodebuildmcp; \
	fi
	@$(XCODEBUILDMCP) --version
	@echo "doctor: OK"

build: build-app build-cli

format-check:
	swift format lint -r Sources Tests

build-app: doctor
	$(XCODEBUILDMCP) macos build \
		--workspace-path "$(WORKSPACE_PATH)" \
		--scheme "$(APP_BUILD_SCHEME)" \
		--configuration "$(CONFIGURATION)" \
		--derived-data-path "$(DERIVED_DATA_PATH)"

build-cli: doctor
	$(XCODEBUILDMCP) macos build \
		--workspace-path "$(WORKSPACE_PATH)" \
		--scheme "$(CLI_BUILD_SCHEME)" \
		--configuration "$(CONFIGURATION)" \
		--derived-data-path "$(DERIVED_DATA_PATH)"

install-cli:
	swift build -c $(SWIFT_CONFIGURATION) --product $(CLI_PRODUCT_NAME)
	install -d "$(INSTALL_BIN_DIR)"
	install -m 755 ".build/$(SWIFT_CONFIGURATION)/$(CLI_PRODUCT_NAME)" "$(INSTALL_BIN_DIR)/$(CLI_PRODUCT_NAME)"

install-zsh-completion:
	@if [ ! -x "$(CLI_COMPLETION_SOURCE)" ]; then \
		echo "error: completion source not found or not executable: $(CLI_COMPLETION_SOURCE)"; \
		echo "hint: run 'make install-cli' first or set CLI_COMPLETION_SOURCE=/path/to/personakit"; \
		exit 1; \
	fi
	install -d "$(ZSH_COMPLETION_DIR)"
	"$(CLI_COMPLETION_SOURCE)" --generate-completion-script zsh > "$(ZSH_COMPLETION_DIR)/_$(CLI_PRODUCT_NAME)"
	@echo "Installed zsh completion to $(ZSH_COMPLETION_DIR)/_$(CLI_PRODUCT_NAME)"
	@echo "If needed, add this to ~/.zshrc:"
	@echo "  fpath=($(ZSH_COMPLETION_DIR) \$$fpath)"
	@echo "  autoload -Uz compinit"
	@echo "  compinit"

run: doctor
	@echo "Stopping existing $(APP_NAME) instances via XcodeBuildMCP..."
	@$(XCODEBUILDMCP) macos stop --app-name "$(APP_NAME)" >/dev/null 2>&1 || true
	$(XCODEBUILDMCP) macos build-and-run \
		--workspace-path "$(WORKSPACE_PATH)" \
		--scheme "$(RUN_SCHEME)" \
		--configuration "$(CONFIGURATION)" \
		--derived-data-path "$(DERIVED_DATA_PATH)"

test: doctor
	swift test $(if $(TEST_FILTER),--filter $(TEST_FILTER),)
	@if [ -z "$(TEST_FILTER)" ]; then \
		$(XCODEBUILDMCP) macos stop --app-name "$(APP_NAME)" >/dev/null 2>&1 || true; \
		xcodebuild \
			-workspace "$(WORKSPACE_PATH)" \
			-scheme "PersonaKit" \
			-configuration "$(CONFIGURATION)" \
			-derivedDataPath "$(DERIVED_DATA_PATH)" \
			test; \
	fi

test-cli:
	swift test --filter $(if $(TEST_FILTER),$(TEST_FILTER),CLI)

pkg-preflight:
	@if ! command -v xcodebuild >/dev/null 2>&1; then \
		echo "error: xcodebuild is required."; \
		exit 1; \
	fi
	@if ! command -v productbuild >/dev/null 2>&1; then \
		echo "error: productbuild is required."; \
		exit 1; \
	fi
	@if ! command -v pkgbuild >/dev/null 2>&1; then \
		echo "error: pkgbuild is required."; \
		exit 1; \
	fi
	@if ! command -v xcrun >/dev/null 2>&1; then \
		echo "error: xcrun is required."; \
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
	@if [ ! -f "$(PKG_EXPORT_OPTIONS_PLIST)" ]; then \
		echo "error: export options plist not found at $(PKG_EXPORT_OPTIONS_PLIST)"; \
		exit 1; \
	fi
	@echo "pkg-preflight: OK"

archive-app-release: pkg-preflight
	@mkdir -p "$(dir $(PKG_ARCHIVE_PATH))"
	xcodebuild archive \
		-workspace "$(WORKSPACE_PATH)" \
		-scheme "$(RUN_SCHEME)" \
		-configuration "$(CONFIGURATION)" \
		-destination "generic/platform=macOS" \
		-archivePath "$(PKG_ARCHIVE_PATH)" \
		ONLY_ACTIVE_ARCH=NO \
		ARCHS="$(PKG_ARCHS)"

export-app-release:
	@if [ ! -d "$(PKG_ARCHIVE_PATH)" ]; then \
		echo "error: archive not found at $(PKG_ARCHIVE_PATH)"; \
		echo "hint: run 'make archive-app-release' first"; \
		exit 1; \
	fi
	@mkdir -p "$(PKG_BUILD_DIR)"
	@rm -rf "$(PKG_EXPORT_PATH)"
	xcodebuild -exportArchive \
		-archivePath "$(PKG_ARCHIVE_PATH)" \
		-exportOptionsPlist "$(PKG_EXPORT_OPTIONS_PLIST)" \
		-exportPath "$(PKG_EXPORT_PATH)"
	@if [ ! -d "$(PKG_EXPORT_PATH)/$(APP_NAME).app" ]; then \
		echo "error: exported app not found at $(PKG_EXPORT_PATH)/$(APP_NAME).app"; \
		exit 1; \
	fi

pkg-app:
	@if [ ! -d "$(PKG_EXPORT_PATH)/$(APP_NAME).app" ]; then \
		echo "error: exported app not found at $(PKG_EXPORT_PATH)/$(APP_NAME).app"; \
		echo "hint: run 'make export-app-release' first"; \
		exit 1; \
	fi
	@if [ -z "$(INSTALLER_SIGN_IDENTITY)" ]; then \
		echo "error: INSTALLER_SIGN_IDENTITY is required."; \
		exit 1; \
	fi
	@mkdir -p "$(dir $(PKG_OUTPUT_PATH))"
	@rm -rf "$(PKG_STAGE_ROOT)"
	@mkdir -p "$(PKG_STAGE_ROOT)$(APP_INSTALL_LOCATION)"
	# Preserve the signed app bundle shape while packaging it as a non-relocatable installer component.
	@ditto --norsrc --noqtn "$(PKG_EXPORT_PATH)/$(APP_NAME).app" "$(PKG_STAGE_ROOT)$(APP_INSTALL_LOCATION)/$(APP_NAME).app"
	@xattr -cr "$(PKG_STAGE_ROOT)"
	@find "$(PKG_STAGE_ROOT)" -name '._*' -delete
	@pkgbuild --analyze --root "$(PKG_STAGE_ROOT)" "$(PKG_COMPONENT_PLIST)"
	@/usr/libexec/PlistBuddy -c "Set :0:BundleIsRelocatable false" "$(PKG_COMPONENT_PLIST)"
	@/usr/libexec/PlistBuddy -c "Set :0:BundleHasStrictIdentifier true" "$(PKG_COMPONENT_PLIST)"
	@/usr/libexec/PlistBuddy -c "Set :0:BundleOverwriteAction upgrade" "$(PKG_COMPONENT_PLIST)"
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

notarize-pkg:
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		echo "hint: run 'make pkg-app INSTALLER_SIGN_IDENTITY=…' first"; \
		exit 1; \
	fi
	@if [ -z "$(NOTARY_KEYCHAIN_PROFILE)" ]; then \
		echo "error: NOTARY_KEYCHAIN_PROFILE is required."; \
		exit 1; \
	fi
	xcrun notarytool submit "$(PKG_OUTPUT_PATH)" \
		--keychain-profile "$(NOTARY_KEYCHAIN_PROFILE)" \
		--wait

staple-pkg:
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		echo "hint: run 'make pkg-app INSTALLER_SIGN_IDENTITY=…' first"; \
		exit 1; \
	fi
	xcrun stapler staple "$(PKG_OUTPUT_PATH)"

verify-pkg:
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		echo "hint: run 'make pkg-app INSTALLER_SIGN_IDENTITY=…' first"; \
		exit 1; \
	fi
	pkgutil --check-signature "$(PKG_OUTPUT_PATH)"
	xcrun stapler validate "$(PKG_OUTPUT_PATH)"
	@echo "verify-pkg: signature and stapling look good."
	@echo "verify-pkg: if 'pkgutil --payload-files' shows synthetic ._* entries, trust the installed /Applications bundle and Gatekeeper checks."

release-pkg: pkg-preflight archive-app-release export-app-release pkg-app notarize-pkg staple-pkg verify-pkg

cli:
	personakit $(ARGS)

init:
	@dest="$(CURDIR)/.personakit"; \
	if [ -e "$$dest" ]; then \
		printf "%s already exists.\n" "$$dest"; \
	else \
		personakit init "$$dest"; \
	fi

validate:
	personakit validate $(SCOPE_ARGS)

validate-repo:
	PERSONAKIT_VALIDATE_TMP_ROOT=$(VALIDATE_TMPDIR) ./Scripts/validate-repo.sh

complete-worktree:
	./Scripts/complete-worktree.sh \
		$(if $(COMPLETE_WORKTREE_BRANCH),--branch $(COMPLETE_WORKTREE_BRANCH),) \
		$(if $(COMPLETE_WORKTREE_PATH),--worktree $(COMPLETE_WORKTREE_PATH),) \
		--main $(COMPLETE_WORKTREE_MAIN) \
		$(if $(filter 1 true yes,$(COMPLETE_WORKTREE_NO_CLEANUP)),--no-cleanup,)

export:
	personakit export $(SCOPE_ARGS) --session $(SESSION) --output $(OUTPUT)

list:
	@if [ -z "$(TYPE)" ]; then \
		printf "Missing TYPE. Example: make list TYPE=personas\n"; \
		exit 1; \
	fi
	personakit list $(SCOPE_ARGS) $(TYPE)

graph:
	personakit graph $(SCOPE_ARGS) --session $(SESSION)

zip:
	zip -r $(ZIP_NAME) . \
		-x "*.git/*" \
		-x "__MACOSX/*" \
		-x "*.DS_Store" \
		-x "*/.DS_Store" \
		-x "._*" \
		-x ".build/*" \
		-x "*/DerivedData/*"
