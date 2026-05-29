#!/usr/bin/env bash
#
# Category: git
#
# Installs git + delta + gnupg + gum and links the gitconfig fragments under
# ~/.config/git/. The shell-side `git` function override lives at
# scripts/overrides/git.sh and is wired into bashrc by the `shell` category —
# this category does not touch the shell.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/os.sh
source "${DOTFILES_ROOT}/scripts/lib/os.sh"
# shellcheck source=../lib/link.sh
source "${DOTFILES_ROOT}/scripts/lib/link.sh"
# shellcheck source=../lib/pkg.sh
source "${DOTFILES_ROOT}/scripts/lib/pkg.sh"

CATEGORY=git

# Symlink mappings: "<repo path relative to root>:<absolute destination>"
# Note: ~/.config/git/config-artifex is NOT a symlink — it's rendered at
# setup time by scripts/setup/secrets.sh from the sops-encrypted secrets
# file. Same goes for ~/.config/git/profiles.d/artifex.env, which the
# linked profiles.sh sources conditionally.
LINKS=(
	"home/.config/git/config:${HOME}/.config/git/config"
	"home/.config/git/ignore:${HOME}/.config/git/ignore"
	"home/.config/git/profiles.sh:${HOME}/.config/git/profiles.sh"
)

cmd_install() {
	log_step "${CATEGORY}: install packages"
	pkg_apt_install git git-delta gnupg2 gum
}

cmd_link() {
	log_step "${CATEGORY}: link"
	local entry src dest
	for entry in "${LINKS[@]}"; do
		src=${entry%%:*}
		dest=${entry#*:}
		link_file "${DOTFILES_ROOT}/${src}" "${dest}"
	done
}

cmd_unlink() {
	log_step "${CATEGORY}: unlink"
	local entry dest
	for entry in "${LINKS[@]}"; do
		dest=${entry#*:}
		unlink_file "${dest}"
	done
}

cmd_status() {
	log_step "${CATEGORY}: status"
	local entry dest
	for entry in "${LINKS[@]}"; do
		dest=${entry#*:}
		link_status "${dest}"
	done
}

main() {
	local subcmd=${1:-}
	case ${subcmd} in
		install|link|unlink|status)
			"cmd_${subcmd}"
			;;
		"")
			die "usage: $0 {install|link|unlink|status}"
			;;
		*)
			die "unknown subcommand: ${subcmd}"
			;;
	esac
}

main "$@"
