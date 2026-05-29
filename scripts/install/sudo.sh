#!/usr/bin/env bash
#
# Category: sudo
#
# Drop the sudo timeout / lecture-once snippet into /etc/sudoers.d/. Validates
# with `visudo -c -f` before swapping into place — invalid sudoers files
# brick sudo until repaired via root or single-user mode.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/os.sh
source "${DOTFILES_ROOT}/scripts/lib/os.sh"
# shellcheck source=../lib/system.sh
source "${DOTFILES_ROOT}/scripts/lib/system.sh"

CATEGORY=sudo

SRC="${DOTFILES_ROOT}/system/etc/sudoers.d/99-dotfiles-timeout"
DEST="/etc/sudoers.d/99-dotfiles-timeout"

cmd_install() {
	system_require_ubuntu || return 0
	log_step "${CATEGORY}: install (visudo-validated)"
	# Mode 0440 is the conventional mode for sudoers.d entries — anything
	# else gets ignored by sudo.
	system_install_validated "${SRC}" "${DEST}" 0440 "sudo visudo -c -f"
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
