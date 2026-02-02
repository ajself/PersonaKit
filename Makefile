.DEFAULT_GOAL := help

ROOT ?=
PERSONA ?= senior-swiftui-engineer
TASK ?= apply-style
KITS ?=
OUTPUT ?= /tmp/session.md
ARGS ?=
ZIP_NAME ?= PersonaKit_review.zip
NO_PROJECT ?= 0
NO_GLOBAL ?= 0
PREFIX ?= /usr/local
INSTALL_DIR ?= $(PREFIX)/bin

ROOT_ARG := $(if $(ROOT),--root $(ROOT),)
SCOPE_ARGS := $(ROOT_ARG) $(if $(filter 1 true yes,$(NO_PROJECT)),--no-project,) $(if $(filter 1 true yes,$(NO_GLOBAL)),--no-global,)

.PHONY: help
help:
	@printf "Usage:\n"
	@printf "  make <target> [VAR=value]\n\n"
	@printf "Common targets:\n"
	@printf "  help            Show this help message\n"
	@printf "  build           Build the CLI\n"
	@printf "  install         Build release and install to INSTALL_DIR\n"
	@printf "  test            Run tests\n"
	@printf "  run             Run the CLI with ARGS\n\n"
	@printf "  docc-preview    Preview DocC tutorials\n\n"
	@printf "Project workflow:\n"
	@printf "  init            Initialize a starter kit in ./.personakit\n"
	@printf "  validate        Validate using scope discovery (or ROOT override)\n"
	@printf "  export          Export a session prompt to OUTPUT\n"
	@printf "  list            List entities (TYPE=personas|kits|tasks|intents|skills|essentials)\n"
	@printf "  graph           Print the resolution graph\n\n"
	@printf "  zip             Create a review zip (excluding VCS/build/OS files)\n\n"
	@printf "Variables:\n"
	@printf "  ROOT            Root kit path override (optional)\n"
	@printf "  PERSONA         Persona id (default: %s)\n" "$(PERSONA)"
	@printf "  TASK            Task id (default: %s)\n" "$(TASK)"
	@printf "  KITS            Comma-separated kit overrides (optional)\n"
	@printf "  OUTPUT          Export output path (default: %s)\n" "$(OUTPUT)"
	@printf "  ARGS            Arguments passed to 'swift run personakit'\n"
	@printf "  NO_PROJECT      Set to 1 to disable project scope discovery\n"
	@printf "  NO_GLOBAL       Set to 1 to disable global scope discovery\n"
	@printf "  PREFIX          Install prefix (default: %s)\n" "$(PREFIX)"
	@printf "  INSTALL_DIR     Install directory (default: %s)\n" "$(INSTALL_DIR)"
	@printf "  ZIP_NAME        Zip file name (default: %s)\n" "$(ZIP_NAME)"

.PHONY: build
build:
	swift build

.PHONY: install
install:
	swift build -c release
	install -d "$(INSTALL_DIR)"
	install -m 755 ".build/release/personakit" "$(INSTALL_DIR)/personakit"

.PHONY: test
test:
	swift test
	npm --prefix personakit-mcp test

.PHONY: run
run:
	personakit $(ARGS)

.PHONY: docc-preview
docc-preview:
	xcrun docc preview Docs/PersonaKit.docc --fallback-display-name PersonaKit --fallback-bundle-identifier com.ajself.PersonaKit --fallback-bundle-version 1

.PHONY: init
init:
	@dest="$(CURDIR)/.personakit"; \
	if [ -e "$$dest" ]; then \
		printf "%s already exists.\n" "$$dest"; \
	else \
		personakit init "$$dest"; \
	fi

.PHONY: validate
validate:
	personakit validate $(SCOPE_ARGS)

.PHONY: export
export:
	personakit export $(SCOPE_ARGS) --persona $(PERSONA) --task $(TASK) $(if $(KITS),--kits $(KITS),) --output $(OUTPUT)

.PHONY: list
list:
	@if [ -z "$(TYPE)" ]; then \
		printf "Missing TYPE. Example: make list TYPE=personas\n"; \
		exit 1; \
	fi
	personakit list $(SCOPE_ARGS) $(TYPE)

.PHONY: graph
graph:
	personakit graph $(SCOPE_ARGS) --persona $(PERSONA) --task $(TASK) $(if $(KITS),--kits $(KITS),)

.PHONY: zip
zip:
	zip -r $(ZIP_NAME) . \
	-x "*.git/*" \
	-x "__MACOSX/*" \
	-x "*.DS_Store" \
	-x "*/.DS_Store" \
	-x "._*" \
	-x "*.build/*" \
	-x "*personakkit-mcp/node_modules/*"
