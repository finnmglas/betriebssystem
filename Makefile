# BETRIEBSSYSTEM -- convenience wrapper around scripts/.
# The actual ISO build needs root; targets that do shell out to sudo.

SHELL := /bin/bash
VERSION := $(shell cat VERSION)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@echo "BETRIEBSSYSTEM $(VERSION)"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[1;37m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: branding
branding: ## Regenerate all white-circle branding assets
	python3 branding/generate.py

.PHONY: deps
deps: ## Install host build dependencies (root)
	sudo ./scripts/bootstrap-deps.sh

.PHONY: build
build: ## Build a dev ISO (root)
	sudo ./scripts/build.sh

.PHONY: release
release: ## Build a release ISO with build tells scrubbed (root)
	sudo RELEASE=1 ./scripts/build.sh

.PHONY: archive
archive: ## File the newest dist ISO into archive/ stamped with the commit hash
	./scripts/archive-iso.sh

.PHONY: run
run: ## Boot the newest ISO in QEMU (BIOS)
	./scripts/run-qemu.sh

.PHONY: run-uefi
run-uefi: ## Boot the newest ISO in QEMU (UEFI/OVMF)
	./scripts/run-qemu.sh --uefi

.PHONY: run-install
run-install: ## Boot newest ISO with a blank target disk to test installing
	./scripts/run-qemu.sh --uefi --disk

.PHONY: clean
clean: ## Remove build artifacts (keep package cache)
	sudo lb clean noauto 2>/dev/null || true
	rm -f build.log

.PHONY: distclean
distclean: ## Remove everything regenerable (artifacts, cache, dist, run)
	sudo lb clean --purge 2>/dev/null || true
	rm -rf .build cache chroot binary dist run build.log config/binary config/bootstrap config/chroot config/common config/source
