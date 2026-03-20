.DEFAULT_GOAL := help

XCODEBUILDMCP ?= xcodebuildmcp
WORKSPACE_PATH ?= PersonaKit.xcworkspace
RUN_SCHEME ?= PersonaKit
APP_NAME ?= PersonaKit
APP_BUILD_SCHEME ?= PersonaKitStudio
CLI_BUILD_SCHEME ?= PersonaKitCLI
CONFIGURATION ?= Debug
SWIFT_CONFIGURATION ?= debug
DERIVED_DATA_PATH ?= .build/DerivedData
ZIP_NAME ?= PersonaKit.zip
INSTALL_BIN_DIR ?= /usr/local/bin
CLI_PRODUCT_NAME ?= personakit
CLI_COMPLETION_SOURCE ?= $(INSTALL_BIN_DIR)/$(CLI_PRODUCT_NAME)
ZSH_COMPLETION_DIR ?= $(HOME)/.zsh/completions
TEST_FILTER ?=

ROOT ?=
PERSONA ?= senior-swiftui-engineer
DIRECTIVE ?= apply-style
KITS ?=
OUTPUT ?= /tmp/session.md
TYPE ?=
ARGS ?=
NO_PROJECT ?= 0
NO_GLOBAL ?= 0

VALIDATE_AGENT ?= local
VALIDATE_USER ?= $(if $(USER),$(USER),unknown)
VALIDATE_TMPDIR ?= /tmp/personakit-$(VALIDATE_USER)-$(VALIDATE_AGENT)

CLOSEOUT_BRANCH ?=
CLOSEOUT_WORKTREE ?=
CLOSEOUT_MAIN ?= main
CLOSEOUT_NO_CLEANUP ?= 0

ROOT_ARG := $(if $(ROOT),--root $(ROOT),)
SCOPE_ARGS := $(ROOT_ARG) $(if $(filter 1 true yes,$(NO_PROJECT)),--no-project,) $(if $(filter 1 true yes,$(NO_GLOBAL)),--no-global,)

.PHONY: help doctor build build-app build-cli install_cli install_zsh_completion run test test-cli cli init validate validate-repo closeout-local orbit-live-db-proof orbit-live-db-proof-local orbit-transport-proof orbit-transport-soak-local orbit-m3-proof-local export list graph zip format-check

help:
	@echo "PersonaKit Makefile Commands"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [VAR=value]"
	@echo ""
	@echo "XcodeBuildMCP targets:"
	@printf "  %-24s %s\n" "doctor" "Check required tools and workspace health."
	@printf "  %-24s %s\n" "build" "Build macOS app and CLI with XcodeBuildMCP."
	@printf "  %-24s %s\n" "build-app" "Build macOS app scheme with XcodeBuildMCP."
	@printf "  %-24s %s\n" "build-cli" "Build CLI scheme with XcodeBuildMCP."
	@printf "  %-24s %s\n" "install_cli" "Build the Swift CLI and install it into INSTALL_BIN_DIR."
	@printf "  %-24s %s\n" "install_zsh_completion" "Install zsh completion for the installed personakit CLI."
	@printf "  %-24s %s\n" "run" "Build and run macOS app with XcodeBuildMCP."
	@printf "  %-24s %s\n" "test" "Run SwiftPM tests and default Xcode host/UI smoke checks."
	@printf "  %-24s %s\n" "test-cli" "Run CLI-focused SwiftPM tests (defaults to filter \`CLI\`)."
	@printf "  %-24s %s\n" "zip" "Create a project zip archive."
	@echo ""
	@echo "PersonaKit workflow targets:"
	@printf "  %-24s %s\n" "cli" "Run the personakit CLI directly."
	@printf "  %-24s %s\n" "init" "Initialize a starter kit in ./.personakit."
	@printf "  %-24s %s\n" "validate" "Validate using scope discovery or ROOT override."
	@printf "  %-24s %s\n" "validate-repo" "Run deterministic repo validation."
	@printf "  %-24s %s\n" "closeout-local" "Run local-only closeout workflow."
	@printf "  %-24s %s\n" "orbit-live-db-proof" "Repeat the Orbit live Postgres proof harness using ORBIT_PG_*."
	@printf "  %-24s %s\n" "orbit-live-db-proof-local" "Boot a temp local Postgres instance and run the Orbit live proof harness."
	@printf "  %-24s %s\n" "orbit-transport-proof" "Repeat the Orbit persistent-transport confidence ring."
	@printf "  %-24s %s\n" "orbit-transport-soak-local" "Run a longer local Orbit transport soak over the focused confidence ring."
	@printf "  %-24s %s\n" "orbit-m3-proof-local" "Run the local Orbit M3 proof bundle (transport + temp Postgres live-db)."
	@printf "  %-24s %s\n" "export" "Export a resolved PersonaKit session prompt."
	@printf "  %-24s %s\n" "list" "List PersonaKit entities (requires TYPE)."
	@printf "  %-24s %s\n" "graph" "Render session dependency graph."
	@echo ""
	@echo "Configurable variables:"
	@printf "  %-24s %s\n" "WORKSPACE_PATH" "$(WORKSPACE_PATH)"
	@printf "  %-24s %s\n" "RUN_SCHEME" "$(RUN_SCHEME)"
	@printf "  %-24s %s\n" "APP_NAME" "$(APP_NAME)"
	@printf "  %-24s %s\n" "APP_BUILD_SCHEME" "$(APP_BUILD_SCHEME)"
	@printf "  %-24s %s\n" "CLI_BUILD_SCHEME" "$(CLI_BUILD_SCHEME)"
	@printf "  %-24s %s\n" "CONFIGURATION" "$(CONFIGURATION)"
	@printf "  %-24s %s\n" "SWIFT_CONFIGURATION" "$(SWIFT_CONFIGURATION)"
	@printf "  %-24s %s\n" "DERIVED_DATA_PATH" "$(DERIVED_DATA_PATH)"
	@printf "  %-24s %s\n" "ZIP_NAME" "$(ZIP_NAME)"
	@printf "  %-24s %s\n" "INSTALL_BIN_DIR" "$(INSTALL_BIN_DIR)"
	@printf "  %-24s %s\n" "CLI_PRODUCT_NAME" "$(CLI_PRODUCT_NAME)"
	@printf "  %-24s %s\n" "CLI_COMPLETION_SOURCE" "$(CLI_COMPLETION_SOURCE)"
	@printf "  %-24s %s\n" "ZSH_COMPLETION_DIR" "$(ZSH_COMPLETION_DIR)"
	@printf "  %-24s %s\n" "TEST_FILTER" "$(TEST_FILTER)"
	@printf "  %-24s %s\n" "ROOT" "$(ROOT)"
	@printf "  %-24s %s\n" "PERSONA" "$(PERSONA)"
	@printf "  %-24s %s\n" "DIRECTIVE" "$(DIRECTIVE)"
	@printf "  %-24s %s\n" "KITS" "$(KITS)"
	@printf "  %-24s %s\n" "OUTPUT" "$(OUTPUT)"
	@printf "  %-24s %s\n" "TYPE" "$(TYPE)"
	@printf "  %-24s %s\n" "ARGS" "$(ARGS)"
	@printf "  %-24s %s\n" "NO_PROJECT" "$(NO_PROJECT)"
	@printf "  %-24s %s\n" "NO_GLOBAL" "$(NO_GLOBAL)"
	@echo ""
	@echo "Examples:"
	@echo "  make doctor"
	@echo "  make build [CONFIGURATION=Release]"
	@echo "  make build-app [APP_BUILD_SCHEME=PersonaKitStudio] [CONFIGURATION=Release]"
	@echo "  make build-cli [CLI_BUILD_SCHEME=PersonaKitCLI] [CONFIGURATION=Release]"
	@echo "  make install_cli [SWIFT_CONFIGURATION=release] [INSTALL_BIN_DIR=/usr/local/bin]"
	@echo "  make install_zsh_completion [CLI_COMPLETION_SOURCE=/usr/local/bin/personakit]"
	@echo "  make run [RUN_SCHEME=PersonaKit] [APP_NAME=PersonaKit]"
	@echo "  make test [TEST_FILTER=TaskboardSnapshotTests]"
	@echo "  make test-cli [TEST_FILTER=CLISessionTests]"
	@echo "  make cli [ARGS=\"list personas\"]"
	@echo "  make validate [ROOT=/Users/me/Code/PersonaKit/.personakit] [NO_GLOBAL=1]"
	@echo "  make export [PERSONA=architectural-editor] [DIRECTIVE=review-architecture-invariants] [OUTPUT=/tmp/session.md]"
	@echo "  make list [TYPE=personas] [ROOT=/Users/me/Code/PersonaKit/.personakit]"
	@echo "  make graph [PERSONA=architectural-editor] [DIRECTIVE=review-architecture-invariants]"
	@echo "  make zip [ZIP_NAME=PersonaKit-archive.zip]"

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

install_cli:
	swift build -c $(SWIFT_CONFIGURATION) --product $(CLI_PRODUCT_NAME)
	install -d "$(INSTALL_BIN_DIR)"
	install -m 755 ".build/$(SWIFT_CONFIGURATION)/$(CLI_PRODUCT_NAME)" "$(INSTALL_BIN_DIR)/$(CLI_PRODUCT_NAME)"

install_zsh_completion:
	@if [ ! -x "$(CLI_COMPLETION_SOURCE)" ]; then \
		echo "error: completion source not found or not executable: $(CLI_COMPLETION_SOURCE)"; \
		echo "hint: run 'make install_cli' first or set CLI_COMPLETION_SOURCE=/path/to/personakit"; \
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

closeout-local:
	./Scripts/closeout-local.sh \
		$(if $(CLOSEOUT_BRANCH),--branch $(CLOSEOUT_BRANCH),) \
		$(if $(CLOSEOUT_WORKTREE),--worktree $(CLOSEOUT_WORKTREE),) \
		--main $(CLOSEOUT_MAIN) \
		$(if $(filter 1 true yes,$(CLOSEOUT_NO_CLEANUP)),--no-cleanup,)

orbit-live-db-proof:
	./Scripts/run-orbit-live-db-proof.sh

orbit-live-db-proof-local:
	./Scripts/run-orbit-live-db-proof.sh --local-temp-postgres

orbit-transport-proof:
	./Scripts/run-orbit-transport-proof.sh

orbit-transport-soak-local:
	./Scripts/run-orbit-transport-soak-local.sh

orbit-m3-proof-local:
	./Scripts/run-orbit-m3-proof-local.sh

export:
	personakit export $(SCOPE_ARGS) --persona $(PERSONA) --directive $(DIRECTIVE) $(if $(KITS),--kits $(KITS),) --output $(OUTPUT)

list:
	@if [ -z "$(TYPE)" ]; then \
		printf "Missing TYPE. Example: make list TYPE=personas\n"; \
		exit 1; \
	fi
	personakit list $(SCOPE_ARGS) $(TYPE)

graph:
	personakit graph $(SCOPE_ARGS) --persona $(PERSONA) --directive $(DIRECTIVE) $(if $(KITS),--kits $(KITS),)

zip:
	zip -r $(ZIP_NAME) . \
		-x "*.git/*" \
		-x "__MACOSX/*" \
		-x "*.DS_Store" \
		-x "*/.DS_Store" \
		-x "._*" \
		-x ".build/*" \
		-x "*/DerivedData/*"
