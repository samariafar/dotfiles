# Ubuntu Configuration Makefile

# Special targets
.ONESHELL:
.DELETE_ON_ERROR:
.SHELLFLAGS := -eu -o pipefail -c

# Silent by default — set DEBUG=true to echo each command before running it
ifneq ($(DEBUG),true)
.SILENT:
endif

# Declare phony targets
.PHONY: help bootstrap secrets apply link unlink status update capture diff lint fmt

# Repository root resolved at parse time
DOTFILES_ROOT := $(CURDIR)

# Every category drops a script under scripts/install/. Sorted so the order is
# stable across runs (filesystem ordering is not guaranteed).
INSTALL_SCRIPTS := $(sort $(wildcard $(DOTFILES_ROOT)/scripts/install/*.sh))

# Reverse-direction tooling — capture the live system state and diff against
# what the repo declares.
CAPTURE_SCRIPTS := $(sort $(wildcard $(DOTFILES_ROOT)/scripts/capture/*.sh))

# Default shell
SHELL := bash

# Default target
.DEFAULT_GOAL := help

# Help command - shows all available targets
help:
	cat <<-EOF
	Ubuntu Configuration

	Setup:
	  make bootstrap   - First-time interactive setup (runs setup.sh)
	  make secrets     - Decrypt secrets.yaml and render private config files
	  make apply       - Run install + link for every category (non-interactive)

	Linking (dotfiles):
	  make link        - Link all configured dotfile categories into \$$HOME
	  make unlink      - Remove our symlinks (originals stay in ~/.dotfiles-backup/)
	  make status      - Show what is linked / foreign / missing

	Packages:
	  make update      - Refresh apt + snap + flatpak indices

	Drift detection:
	  make capture     - Snapshot live system state into var/captured/
	  make diff        - Show what differs between system and repo

	Development:
	  make lint        - shellcheck on every shell script
	  make fmt         - shfmt -w on every shell script

	Variables (export to override):
	  DEBUG=true       - echo each shell command before running it

	Repo: $(DOTFILES_ROOT)
	EOF

# First-time interactive setup
bootstrap:
	exec $(DOTFILES_ROOT)/setup.sh

# Decrypt secrets.yaml and render any private config files referenced by the
# install categories. Idempotent — re-renders on each run. Skips cleanly when
# sops / age / the user's age key isn't available.
secrets:
	bash $(DOTFILES_ROOT)/scripts/setup/secrets.sh install

# Run every category's install + link step (non-interactive). Secret rendering
# runs first so anything referencing private config (e.g. ~/.config/git/config
# includeIf -> ~/.config/git/config-artifex) finds it in place.
apply: secrets
	if [[ -z "$(INSTALL_SCRIPTS)" ]]; then
		echo "no dotfile categories wired up yet — drop scripts/install/<category>.sh"
		exit 0
	fi
	for script in $(INSTALL_SCRIPTS); do
		bash "$$script" install
		bash "$$script" link
	done

# Link all configured dotfile categories into the user's HOME
link:
	if [[ -z "$(INSTALL_SCRIPTS)" ]]; then
		echo "no dotfile categories wired up yet — drop scripts/install/<category>.sh"
		exit 0
	fi
	for script in $(INSTALL_SCRIPTS); do
		bash "$$script" link
	done

# Remove our symlinks (originals remain under ~/.dotfiles-backup/)
unlink:
	if [[ -z "$(INSTALL_SCRIPTS)" ]]; then
		echo "no dotfile categories wired up yet"
		exit 0
	fi
	for script in $(INSTALL_SCRIPTS); do
		bash "$$script" unlink
	done

# Show what is linked / foreign / missing for each category
status:
	if [[ -z "$(INSTALL_SCRIPTS)" ]]; then
		echo "no dotfile categories wired up yet"
		exit 0
	fi
	for script in $(INSTALL_SCRIPTS); do
		bash "$$script" status
	done

# Snapshot the current state of the live system (installed packages, enabled
# GNOME extensions, dconf settings, Firefox extensions). Output lands under
# var/captured/ (gitignored). Use `make diff` to compare against the repo's
# declarations.
capture:
	if [[ -z "$(CAPTURE_SCRIPTS)" ]]; then
		echo "no capture scripts wired up yet"
		exit 0
	fi
	for script in $(CAPTURE_SCRIPTS); do
		bash "$$script" capture
	done

# Per-category diff between the live system (last captured) and the repo
# declarations. Read-only — surfaces drift, never auto-applies it.
diff:
	if [[ -z "$(CAPTURE_SCRIPTS)" ]]; then
		echo "no capture scripts wired up yet"
		exit 0
	fi
	for script in $(CAPTURE_SCRIPTS); do
		bash "$$script" diff
	done

# Refresh package indices for every available source
update:
	echo "==> apt"
	sudo apt-get update
	if command -v snap >/dev/null 2>&1; then
		echo "==> snap"
		sudo snap refresh
	fi
	if command -v flatpak >/dev/null 2>&1; then
		echo "==> flatpak"
		flatpak update -y
	fi

# Lint every shell script in the repo
lint:
	find $(DOTFILES_ROOT) \
		-type d \( -name .git -o -name .claude -o -name docs \) -prune -o \
		-type f \( -name '*.sh' -o -name 'setup.sh' \) -print0 \
		| xargs -0 --no-run-if-empty shellcheck --shell=bash --external-sources

# Format every shell script in the repo (tabs, per code-style skill)
fmt:
	find $(DOTFILES_ROOT) \
		-type d \( -name .git -o -name .claude -o -name docs \) -prune -o \
		-type f \( -name '*.sh' -o -name 'setup.sh' \) -print0 \
		| xargs -0 --no-run-if-empty shfmt -w -i 0 -ci -bn
