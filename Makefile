.DEFAULT_GOAL := help

SWIFT ?= swift

.PHONY: help format lint test

help:
	@printf "%s\n" \
		"PersonaKit Makefile targets:" \
		"  make format          Format Swift files with swift-format" \
		"  make lint            Lint with SwiftLint" \
		"  make test            Run SwiftPM tests" \
		"" \
		"Variables:" \
		"  SWIFT=swift            Swift toolchain command"

format:
	@swift-format format --configuration swift-format.json --in-place --recursive Sources Tests

lint:
	@swiftlint --config .swiftlint.yml

test:
	@$(SWIFT) test
