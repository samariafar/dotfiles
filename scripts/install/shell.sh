#!/usr/bin/env bash
#
# Category: shell
#
# Installs the bash environment: CLI tooling (eza, bat, fd, ripgrep, fzf,
# zoxide, btop, …), the Starship prompt, and links ~/.bashrc / ~/.profile /
# starship config. Also symlinks the scripts/{commands,overrides}/ directories
# under ~/.config/bash/ so .bashrc can source them.

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

CATEGORY=shell

# Symlink mappings: "<repo path relative to root>:<absolute destination>"
# The two `scripts/{commands,overrides}` entries deliberately link the
# *directory*, not individual files — this keeps the symlink set stable as new
# commands are added without touching the install script.
LINKS=(
	"home/.bashrc:${HOME}/.bashrc"
	"home/.profile:${HOME}/.profile"
	"home/.config/mimeapps.list:${HOME}/.config/mimeapps.list"
	"home/.config/starship.toml:${HOME}/.config/starship.toml"
	"home/.config/tmux/tmux.conf:${HOME}/.config/tmux/tmux.conf"
	"home/.config/zed/settings.json:${HOME}/.config/zed/settings.json"
	"scripts/commands:${HOME}/.config/bash/commands"
	"scripts/overrides:${HOME}/.config/bash/overrides"
)

# Apt packages providing the shell environment + tools referenced by the
# aliases / hooks in home/.bashrc. Kept in alphabetical order.
APT_PACKAGES=(
	bash-completion
	bat
	btop
	direnv
	eza
	fd-find
	fzf
	ncdu
	ripgrep
	starship
	tmux
	wl-clipboard
	zoxide
)

# Ubuntu renames a couple of CLIs to avoid namespace conflicts with older
# packages. Shim them under ~/.local/bin so the upstream names work.
shim_renamed_binaries() {
	mkdir -p "${HOME}/.local/bin"
	local upstream src
	declare -A renames=(
		[bat]=batcat
		[fd]=fdfind
	)
	for upstream in "${!renames[@]}"; do
		src=${renames[${upstream}]}
		if [[ ! -e "${HOME}/.local/bin/${upstream}" ]] && command -v "${src}" >/dev/null 2>&1; then
			ln -s "$(command -v "${src}")" "${HOME}/.local/bin/${upstream}"
			log_info "shimmed ${src} → ~/.local/bin/${upstream}"
		fi
	done
}

cmd_install() {
	log_step "${CATEGORY}: install packages"
	pkg_apt_install "${APT_PACKAGES[@]}"
	shim_renamed_binaries
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
