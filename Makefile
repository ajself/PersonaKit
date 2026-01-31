.DEFAULT_GOAL := help

ROOT ?= /tmp/PersonaKit
PERSONA ?= senior-swiftui-engineer
TASK ?= apply-style
KITS ?=
OUTPUT ?= /tmp/session.md
ARGS ?=
ZIP_NAME ?= PersonaKit_review.zip

.PHONY: help
help:
	@printf "Usage:\n"
	@printf "  make <target> [VAR=value]\n\n"
	@printf "Common targets:\n"
	@printf "  help            Show this help message\n"
	@printf "  build           Build the CLI\n"
	@printf "  test            Run tests\n"
	@printf "  run             Run the CLI with ARGS\n\n"
	@printf "Project workflow:\n"
	@printf "  init            Initialize a starter kit at ROOT (default: %s)\n" "$(ROOT)"
	@printf "  validate        Validate a kit at ROOT\n"
	@printf "  export          Export a session prompt to OUTPUT\n"
	@printf "  list            List entities (TYPE=personas|kits|tasks|intents|skills|essentials)\n"
	@printf "  graph           Print the resolution graph\n\n"
	@printf "  zip             Create a review zip (excluding VCS/build/OS files)\n\n"
	@printf "Variables:\n"
	@printf "  ROOT            Root kit path (default: %s)\n" "$(ROOT)"
	@printf "  PERSONA         Persona id (default: %s)\n" "$(PERSONA)"
	@printf "  TASK            Task id (default: %s)\n" "$(TASK)"
	@printf "  KITS            Comma-separated kit overrides (optional)\n"
	@printf "  OUTPUT          Export output path (default: %s)\n" "$(OUTPUT)"
	@printf "  ARGS            Arguments passed to 'swift run personakit'\n"
	@printf "  ZIP_NAME        Zip file name (default: %s)\n" "$(ZIP_NAME)"

.PHONY: build
build:
	swift build

.PHONY: test
test:
	swift test

.PHONY: run
run:
	swift run personakit $(ARGS)

.PHONY: init
init:
	swift run personakit init $(ROOT)

.PHONY: validate
validate:
	swift run personakit validate --root $(ROOT)

.PHONY: export
export:
	swift run personakit export --root $(ROOT) --persona $(PERSONA) --task $(TASK) $(if $(KITS),--kits $(KITS),) --output $(OUTPUT)

.PHONY: list
list:
	@if [ -z "$(TYPE)" ]; then \
		printf "Missing TYPE. Example: make list TYPE=personas\n"; \
		exit 1; \
	fi
	swift run personakit list --root $(ROOT) $(TYPE)

.PHONY: graph
graph:
	swift run personakit graph --root $(ROOT) --persona $(PERSONA) --task $(TASK) $(if $(KITS),--kits $(KITS),)

.PHONY: zip
zip:
	zip -r $(ZIP_NAME) . -x "*.git/*" -x "__MACOSX/*" -x "*.DS_Store" -x "*/.DS_Store" -x "._*" -x "*.build/*"
