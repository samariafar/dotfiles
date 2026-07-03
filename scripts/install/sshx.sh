#!/usr/bin/env bash
#
# Category: sshx
#
# The `sshx` command reads server declarations from secrets.yaml at runtime
# (see scripts/commands/sshx.sh). This install script only ensures the tools
# it depends on are present — nothing to link or render.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/pkg.sh
source "${DOTFILES_ROOT}/scripts/lib/pkg.sh"

CATEGORY=sshx

APT_PACKAGES=(
	expect
	oathtool
	openssh-client
)

cmd_install() {
	log_step "${CATEGORY}: install packages"
	pkg_apt_install "${APT_PACKAGES[@]}"
}

# No files to link/unlink — sshx.sh is picked up by shell.sh's symlink of
# scripts/commands/ into ~/.config/bash/commands/. The runtime reads
# secrets.yaml directly.
cmd_link()   { :; }
cmd_unlink() { :; }
cmd_status() { printf 'sshx runtime lives under ~/.config/bash/commands/sshx.sh (linked by shell category)\n'; }

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
