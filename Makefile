.DEFAULT_GOAL := help

SWIFT ?= swift
APP_PRODUCT ?= AppOpsCLI
APP_ARGS ?=

.PHONY: help appops appops-help appops-build appops-clean appops-rebuild format lint test

help:
	@printf "%s\n" \
		"PersonaKit Makefile targets:" \
		"  make appops          Run Scripts/appops (use APP_ARGS=...)" \
		"  make appops-help     Show AppOpsCLI help" \
		"  make appops-build    Build AppOpsCLI with SwiftPM (debug)" \
		"  make appops-clean    SwiftPM clean for this package" \
		"  make appops-rebuild  Clean + build AppOpsCLI" \
		"  make format          Format Swift files with swift-format" \
		"  make lint            Lint with SwiftLint" \
		"  make test            Run SwiftPM tests" \
		"" \
		"Variables:" \
		"  APP_ARGS=\"--help\"      Arguments forwarded to Scripts/appops" \
		"  APP_PRODUCT=AppOpsCLI  SwiftPM product (override if needed)" \
		"  SWIFT=swift            Swift toolchain command"

appops:
	@Scripts/appops $(APP_ARGS)

appops-help:
	@Scripts/appops --help

appops-build:
	@$(SWIFT) build -c debug --product $(APP_PRODUCT)

appops-clean:
	@$(SWIFT) package clean

appops-rebuild: appops-clean appops-build

format:
	@swift-format format --configuration swift-format.json --in-place --recursive Sources Tests

lint:
	@swiftlint --config .swiftlint.yml

test:
	@$(SWIFT) test
