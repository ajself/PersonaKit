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
RELEASE_LOCAL_CONFIG ?= Config/Release.local.mk
PKG_BUILD_DIR ?= .build/Release
PKG_ARCHIVE_PATH ?= $(PKG_BUILD_DIR)/$(APP_NAME).xcarchive
PKG_EXPORT_PATH ?= $(PKG_BUILD_DIR)/export
PKG_OUTPUT_PATH ?= $(PKG_BUILD_DIR)/$(APP_NAME).pkg
PKG_STAGE_ROOT ?= $(PKG_BUILD_DIR)/pkgroot
PKG_COMPONENT_PLIST ?= $(PKG_BUILD_DIR)/component.plist
PKG_ARCHS ?= arm64 x86_64
PKG_IDENTIFIER ?= com.ajself.PersonaKit
PKG_VERSION ?= 1.0.0
APP_INSTALL_LOCATION ?= /Applications
APP_SIGN_IDENTITY ?=
INSTALLER_SIGN_IDENTITY ?=
NOTARY_KEYCHAIN_PROFILE ?=
TEST_FILTER ?=
SWIFT ?= swift

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
SWIFTPM_ENV ?= CLANG_MODULE_CACHE_PATH=$(SWIFTPM_CACHE_ROOT)/clang-module-cache TMPDIR=$(SWIFTPM_TMPDIR)
SWIFT_BUILD ?= $(SWIFTPM_ENV) $(SWIFT) build $(SWIFTPM_FLAGS)
SWIFT_RUN ?= $(SWIFTPM_ENV) $(SWIFT) run $(SWIFTPM_FLAGS)
SWIFT_TEST ?= $(SWIFTPM_ENV) $(SWIFT) test $(SWIFTPM_FLAGS)

COMPLETE_WORKTREE_BRANCH ?=
COMPLETE_WORKTREE_PATH ?=
COMPLETE_WORKTREE_MAIN ?= main
COMPLETE_WORKTREE_NO_CLEANUP ?= 0

.PHONY: help studio-doctor clean build test format-check swiftpm-prepare \
	core-validate-repo core-complete-worktree core-zip public-v1-check \
	cli-build cli-install cli-install-zsh-completion cli-test \
	studio-build studio-run studio-test studio-review studio-vqa \
	studio-pkg-preflight studio-archive-release studio-export-release studio-pkg-app studio-notarize-pkg studio-staple-pkg studio-verify-pkg studio-release-pkg

studio-archive-release studio-export-release studio-pkg-app studio-notarize-pkg studio-staple-pkg studio-verify-pkg studio-release-pkg: CONFIGURATION = Release

help:
	@echo "PersonaKit Makefile Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [VAR=value]"
	@echo ""
	@echo "Shared/Core:"
	@printf "  %-28s %s\n" "clean" "Remove SwiftPM, Xcode derived data, and packaging build artifacts."
	@printf "  %-28s %s\n" "build" "Build the default local CLI surface with SwiftPM."
	@printf "  %-28s %s\n" "test" "Run the package test suite with optional TEST_FILTER."
	@printf "  %-28s %s\n" "format-check" "Lint Sources and Tests with swift-format."
	@printf "  %-28s %s\n" "core-validate-repo" "Run deterministic repo validation."
	@printf "  %-28s %s\n" "core-complete-worktree" "Rebase & ff-merge feature branch to main, delete worktree & branch."
	@printf "  %-28s %s\n" "core-zip" "Create a project zip archive."
	@printf "  %-28s %s\n" "public-v1-check" "Run public V1 README and starter verification."
	@echo ""
	@echo "CLI surface:"
	@printf "  %-28s %s\n" "cli-build" "Build the SwiftPM CLI executable."
	@printf "  %-28s %s\n" "cli-install" "Install the SwiftPM CLI executable into INSTALL_BIN_DIR."
	@printf "  %-28s %s\n" "cli-install-zsh-completion" "Install zsh completion for the installed personakit CLI."
	@printf "  %-28s %s\n" "cli-test" "Run CLI-focused SwiftPM tests (defaults to filter CLI)."
	@echo ""
	@echo "Studio surface (optional; not part of the V1 release bar):"
	@printf "  %-28s %s\n" "studio-build" "Build the Studio app target with XcodeBuildMCP."
	@printf "  %-28s %s\n" "studio-run" "Build and run the Studio app with XcodeBuildMCP."
	@printf "  %-28s %s\n" "studio-test" "Run Studio Xcode tests only (requires WORKSPACE_PATH)."
	@printf "  %-28s %s\n" "studio-review" "Build Studio and capture optional review screenshots."
	@printf "  %-28s %s\n" "studio-vqa" "Alias for studio-review."
	@printf "  %-28s %s\n" "studio-pkg-preflight" "Check Studio packaging tools, export options, and release inputs."
	@printf "  %-28s %s\n" "studio-archive-release" "Archive the Studio app for Release distribution."
	@printf "  %-28s %s\n" "studio-export-release" "Copy the signed archived app into the release export directory."
	@printf "  %-28s %s\n" "studio-pkg-app" "Create a signed installer package for the exported Studio app."
	@printf "  %-28s %s\n" "studio-notarize-pkg" "Submit the Studio installer package for notarization."
	@printf "  %-28s %s\n" "studio-staple-pkg" "Staple the notarization ticket to the Studio installer package."
	@printf "  %-28s %s\n" "studio-verify-pkg" "Verify Studio installer signing and stapled notarization."
	@printf "  %-28s %s\n" "studio-release-pkg" "Run the full Studio archive/export/package/notarize/staple/verify flow."

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
	@echo "Removing packaging artifacts..."
	@rm -rf "$(PKG_BUILD_DIR)"
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
	$(XCODEBUILDMCP) macos build \
		--workspace-path "$(WORKSPACE_PATH)" \
		--scheme "$(STUDIO_SCHEME)" \
		--configuration "$(CONFIGURATION)" \
		--derived-data-path "$(DERIVED_DATA_PATH)"

cli-build: swiftpm-prepare
	$(SWIFT_BUILD) -c $(SWIFT_CONFIGURATION) --product $(CLI_PRODUCT_NAME)

cli-install: cli-build
	@bin_dir="$$($(SWIFT_BUILD) -c $(SWIFT_CONFIGURATION) --show-bin-path)"; \
	install -d "$(INSTALL_BIN_DIR)"; \
	install -m 755 "$$bin_dir/$(CLI_PRODUCT_NAME)" "$(INSTALL_BIN_DIR)/$(CLI_PRODUCT_NAME)"; \
	for bundle in "$$bin_dir"/*.bundle; do \
		[ -d "$$bundle" ] || continue; \
		bundle_name="$$(basename "$$bundle")"; \
		rm -rf "$(INSTALL_BIN_DIR)/$$bundle_name"; \
		ditto "$$bundle" "$(INSTALL_BIN_DIR)/$$bundle_name"; \
	done

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

studio-vqa: studio-review

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

studio-pkg-preflight: studio-doctor
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
	@if [ -z "$(APP_SIGN_IDENTITY)" ]; then \
		echo "error: APP_SIGN_IDENTITY is required."; \
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
		ONLY_ACTIVE_ARCH=NO \
		ARCHS="$(PKG_ARCHS)"

studio-export-release:
	@if [ ! -d "$(PKG_ARCHIVE_PATH)" ]; then \
		echo "error: archive not found at $(PKG_ARCHIVE_PATH)"; \
		echo "hint: run 'make studio-archive-release' first"; \
		exit 1; \
	fi
	@if [ ! -d "$(PKG_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app" ]; then \
		echo "error: archived app not found at $(PKG_ARCHIVE_PATH)/Products/Applications/$(APP_NAME).app"; \
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

studio-pkg-app:
	@if [ ! -d "$(PKG_EXPORT_PATH)/$(APP_NAME).app" ]; then \
		echo "error: exported app not found at $(PKG_EXPORT_PATH)/$(APP_NAME).app"; \
		echo "hint: run 'make studio-export-release' first"; \
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

studio-notarize-pkg:
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		echo "hint: run 'make studio-pkg-app INSTALLER_SIGN_IDENTITY=…' first"; \
		exit 1; \
	fi
	@if [ -z "$(NOTARY_KEYCHAIN_PROFILE)" ]; then \
		echo "error: NOTARY_KEYCHAIN_PROFILE is required."; \
		exit 1; \
	fi
	xcrun notarytool submit "$(PKG_OUTPUT_PATH)" \
		--keychain-profile "$(NOTARY_KEYCHAIN_PROFILE)" \
		--wait

studio-staple-pkg:
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		echo "hint: run 'make studio-pkg-app INSTALLER_SIGN_IDENTITY=…' first"; \
		exit 1; \
	fi
	xcrun stapler staple "$(PKG_OUTPUT_PATH)"

studio-verify-pkg:
	@if [ ! -f "$(PKG_OUTPUT_PATH)" ]; then \
		echo "error: installer package not found at $(PKG_OUTPUT_PATH)"; \
		echo "hint: run 'make studio-pkg-app INSTALLER_SIGN_IDENTITY=…' first"; \
		exit 1; \
	fi
	pkgutil --check-signature "$(PKG_OUTPUT_PATH)"
	xcrun stapler validate "$(PKG_OUTPUT_PATH)"
	@echo "studio-verify-pkg: signature and stapling look good."
	@echo "studio-verify-pkg: if 'pkgutil --payload-files' shows synthetic ._* entries, trust the installed /Applications bundle and Gatekeeper checks."

studio-release-pkg: studio-pkg-preflight studio-archive-release studio-export-release studio-pkg-app studio-notarize-pkg studio-staple-pkg studio-verify-pkg

core-validate-repo: swiftpm-prepare
	PERSONAKIT_VALIDATE_TMP_ROOT=$(VALIDATE_TMPDIR) ./Scripts/validate-repo.sh

public-v1-check: swiftpm-prepare
	$(SWIFT_TEST)
	$(SWIFT_RUN) personakit --help
	$(SWIFT_RUN) personakit run --help
	rm -rf /tmp/personakit-public-v1-check
	mkdir -p /tmp/personakit-public-v1-check
	! find .personakit Examples/public-starter/.personakit \( -name .DS_Store -o -name '._*' \) -print | rg .
	diff -qr .personakit Examples/public-starter/.personakit
	$(SWIFT_RUN) personakit validate --root .personakit
	$(SWIFT_RUN) personakit validate --root Fixtures/internal-agent-root/.personakit
	$(SWIFT_RUN) personakit validate --root Fixtures/kit-root
	$(SWIFT_RUN) personakit validate --root Examples/public-starter/.personakit
	$(SWIFT_RUN) personakit contract --root Examples/public-starter/.personakit --session solo-dev-v1 > /tmp/personakit-public-v1-check/example-contract.json
	rg '"sessionId" : "solo-dev-v1"' /tmp/personakit-public-v1-check/example-contract.json
	rg '"authorizedSkillIds" : \[' /tmp/personakit-public-v1-check/example-contract.json
	$(SWIFT_RUN) personakit run --root Examples/public-starter/.personakit --session solo-dev-v1 --agent opencode --dry-run -- "Make a small, reviewable CLI improvement." > /tmp/personakit-public-v1-check/example-dry-run.md
	rg 'session: solo-dev-v1' /tmp/personakit-public-v1-check/example-dry-run.md
	rg '## Task' /tmp/personakit-public-v1-check/example-dry-run.md
	$(SWIFT_RUN) personakit init /tmp/personakit-public-v1-check/.personakit
	$(SWIFT_RUN) personakit validate --root /tmp/personakit-public-v1-check/.personakit
	$(SWIFT_RUN) personakit run --root /tmp/personakit-public-v1-check/.personakit --session solo-dev-v1 --agent opencode --dry-run -- "Make a small, reviewable CLI improvement." > /tmp/personakit-public-v1-check/init-dry-run.md
	rg 'session: solo-dev-v1' /tmp/personakit-public-v1-check/init-dry-run.md
	rg '## Task' /tmp/personakit-public-v1-check/init-dry-run.md
	mkdir -p /tmp/personakit-public-v1-check/non-empty
	printf "occupied\n" > /tmp/personakit-public-v1-check/non-empty/README.md
	! $(SWIFT_RUN) personakit init /tmp/personakit-public-v1-check/non-empty
	$(SWIFT_RUN) personakit init /tmp/personakit-public-v1-check/non-empty --force
	$(SWIFT_RUN) personakit validate --root /tmp/personakit-public-v1-check/non-empty
	! $(SWIFT_RUN) personakit run --root Fixtures/kit-root --session senior-swiftui-engineer_apply-style --agent opencode --dry-run -- "Verify fixture compatibility." > /tmp/personakit-public-v1-check/legacy-rejection.txt 2>&1
	rg 'run agent `opencode` is not authorized' /tmp/personakit-public-v1-check/legacy-rejection.txt
	! rg -n "AJ|Orbit|Taskboard|architectural-editor|Studio release|workflow platform" .personakit README.md Docs Examples CONTRIBUTING.md SECURITY.md CHANGELOG.md AGENTS.md -g "!Docs/PUBLIC_V1_RELEASE_CHECKLIST.md"
	rg -n "memory|orchestration" .personakit README.md Docs Examples CONTRIBUTING.md SECURITY.md CHANGELOG.md AGENTS.md -g "!Docs/PUBLIC_V1_RELEASE_CHECKLIST.md" || true

core-complete-worktree:
	./Scripts/complete-worktree.sh \
		$(if $(COMPLETE_WORKTREE_BRANCH),--branch $(COMPLETE_WORKTREE_BRANCH),) \
		$(if $(COMPLETE_WORKTREE_PATH),--worktree $(COMPLETE_WORKTREE_PATH),) \
		--main $(COMPLETE_WORKTREE_MAIN) \
		$(if $(filter 1 true yes,$(COMPLETE_WORKTREE_NO_CLEANUP)),--no-cleanup,)

core-zip:
	@mkdir -p "$(dir $(ZIP_NAME))"
	@rm -f "$(ZIP_NAME)"
	git ls-files -z | xargs -0 zip -q "$(ZIP_NAME)"
