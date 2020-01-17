# delete default suffixes
.SUFFIXES:
.EXPORT_ALL_VARIABLES:
.DEFAULT_GOAL   := help
THIS_MAKEFILE   :=$(MAKEFILE_LIST)

SHELL           := /bin/bash
SHELL_COMMAND   := bash

THIS_DIR 			  := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

.PHONY: help
help: ## Prints this help
help:
	@grep -E '(^[0-9a-zA-Z_-]+:.*?##.*$$)|(^##)' $(THIS_MAKEFILE) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | sed -e 's/\[32m##/[33m/'

#-----------------------------------------------------------------------------
# TESTS

node_modules/.bin/bats:
	npm ci

.PHONY: tests
tests: ## launch unit tests
tests: node_modules/.bin/bats
	@node_modules/.bin/bats -r tests
