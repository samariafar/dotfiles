#!/usr/bin/env bash
#
# Category: sysctl
#
# Kernel hardening sysctls — drop the snippet into /etc/sysctl.d/ and reload.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/os.sh
source "${DOTFILES_ROOT}/scripts/lib/os.sh"
# shellcheck source=../lib/system.sh
source "${DOTFILES_ROOT}/scripts/lib/system.sh"

CATEGORY=sysctl

SRC="${DOTFILES_ROOT}/system/etc/sysctl.d/99-dotfiles-hardening.conf"
DEST="/etc/sysctl.d/99-dotfiles-hardening.conf"

cmd_install() {
	system_require_ubuntu || return 0
	log_step "${CATEGORY}: install"
	system_install "${SRC}" "${DEST}" 0644
	log_step "${CATEGORY}: reload (sysctl --system)"
	sudo sysctl --system >/dev/null
}

cmd_status() {
	log_step "${CATEGORY}: status"
	if sudo test -r "${DEST}"; then
		printf 'deployed    %s\n' "${DEST}"
	else
		printf 'missing     %s\n' "${DEST}"
	fi
}

cmd_link()   { log_debug "${CATEGORY}: no symlinks managed by this category"; }
cmd_unlink() { log_debug "${CATEGORY}: no symlinks managed by this category"; }

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
