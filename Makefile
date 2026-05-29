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

.PHONY: help studio-doctor clean build test format-check swiftpm-prepare \
	core-validate-repo core-zip public-check \
	cli-build cli-install cli-install-zsh-completion cli-test \
	studio-build studio-run studio-test studio-review

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
	@echo ""
	@echo "Studio app:"
	@printf "  %-28s %s\n" "studio-build" "Build the Studio app target with XcodeBuildMCP."
	@printf "  %-28s %s\n" "studio-run" "Build and run the Studio app with XcodeBuildMCP."
	@printf "  %-28s %s\n" "studio-test" "Run Studio Xcode tests only (requires WORKSPACE_PATH)."
	@printf "  %-28s %s\n" "studio-review" "Build Studio and capture review screenshots."

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
	$(SWIFT_TEST)
	$(SWIFT_RUN) personakit --help
	$(SWIFT_RUN) personakit export --help
	rm -rf /tmp/personakit-public-check
	mkdir -p /tmp/personakit-public-check
	! find .personakit Examples/public-starter/.personakit \( -name .DS_Store -o -name '._*' \) -print | rg .
	diff -qr .personakit Examples/public-starter/.personakit
	$(SWIFT_RUN) personakit validate --root .personakit
	$(SWIFT_RUN) personakit validate --root Fixtures/internal-agent-root/.personakit
	$(SWIFT_RUN) personakit validate --root Fixtures/kit-root
	$(SWIFT_RUN) personakit validate --root Examples/public-starter/.personakit
	$(SWIFT_RUN) personakit contract --root Examples/public-starter/.personakit --session solo-dev > /tmp/personakit-public-check/example-contract.json
	rg '"sessionId" : "solo-dev"' /tmp/personakit-public-check/example-contract.json
	rg '"authorizedSkillIds" : \[' /tmp/personakit-public-check/example-contract.json
	$(SWIFT_RUN) personakit export --root Examples/public-starter/.personakit --session solo-dev > /tmp/personakit-public-check/example-export.md
	rg 'PersonaKit-Output-Version: 1' /tmp/personakit-public-check/example-export.md
	rg '# Persona' /tmp/personakit-public-check/example-export.md
	rg '# Skill Contract' /tmp/personakit-public-check/example-export.md
	rg '# Directive' /tmp/personakit-public-check/example-export.md
	$(SWIFT_RUN) personakit init /tmp/personakit-public-check/.personakit
	$(SWIFT_RUN) personakit validate --root /tmp/personakit-public-check/.personakit
	$(SWIFT_RUN) personakit export --root /tmp/personakit-public-check/.personakit --session solo-dev > /tmp/personakit-public-check/init-export.md
	rg 'PersonaKit-Output-Version: 1' /tmp/personakit-public-check/init-export.md
	rg '# Persona' /tmp/personakit-public-check/init-export.md
	rg '# Skill Contract' /tmp/personakit-public-check/init-export.md
	rg '# Directive' /tmp/personakit-public-check/init-export.md
	mkdir -p /tmp/personakit-public-check/non-empty
	printf "occupied\n" > /tmp/personakit-public-check/non-empty/README.md
	! $(SWIFT_RUN) personakit init /tmp/personakit-public-check/non-empty
	$(SWIFT_RUN) personakit init /tmp/personakit-public-check/non-empty --force
	$(SWIFT_RUN) personakit validate --root /tmp/personakit-public-check/non-empty
	! rg -n "A[J]|O[r]bit|T[ask]board|architectural-editor|Studio release|workflow platform" .personakit README.md Docs Examples AGENTS.md
	rg -n "memory|orchestration" .personakit README.md Docs Examples AGENTS.md || true

core-zip:
	@mkdir -p "$(dir $(ZIP_NAME))"
	@rm -f "$(ZIP_NAME)"
	git ls-files -z | xargs -0 zip -q "$(ZIP_NAME)"
