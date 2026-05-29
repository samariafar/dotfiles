#!/usr/bin/env bash
#
# Category: sshd
#
# Installs openssh-server, deploys the hardened sshd_config snippet under
# /etc/ssh/sshd_config.d/, but does NOT enable the service. Enabling is a
# conscious step taken with the --enable flag once the operator has:
#   1. seeded ~/.ssh/authorized_keys with a public key
#   2. run `google-authenticator` (libpam-google-authenticator) to set up TOTP
#   3. confirmed UFW (if enabled) allows port 7747

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/os.sh
source "${DOTFILES_ROOT}/scripts/lib/os.sh"
# shellcheck source=../lib/pkg.sh
source "${DOTFILES_ROOT}/scripts/lib/pkg.sh"
# shellcheck source=../lib/system.sh
source "${DOTFILES_ROOT}/scripts/lib/system.sh"

CATEGORY=sshd

SRC="${DOTFILES_ROOT}/system/etc/ssh/sshd_config.d/50-dotfiles-hardening.conf"
DEST="/etc/ssh/sshd_config.d/50-dotfiles-hardening.conf"

cmd_install() {
	system_require_ubuntu || return 0
	log_step "${CATEGORY}: install"
	pkg_apt_install openssh-server libpam-google-authenticator
	system_install_validated "${SRC}" "${DEST}" 0644 "sudo sshd -t -f"
	# Keep the service masked until the operator explicitly opts in.
	if systemctl is-enabled ssh.service >/dev/null 2>&1; then
		log_warn "${CATEGORY}: ssh.service is enabled — disabling per dotfiles default"
		sudo systemctl disable --now ssh.service
	fi
	log_info "${CATEGORY}: run 'bash ${BASH_SOURCE[0]} enable' once TOTP + authorized_keys are in place"
}

cmd_enable() {
	system_require_ubuntu || return 0
	log_step "${CATEGORY}: enabling sshd"
	if [[ ! -s "${HOME}/.ssh/authorized_keys" ]]; then
		die "${CATEGORY}: refusing to enable — ${HOME}/.ssh/authorized_keys is empty/missing"
	fi
	if [[ ! -s "${HOME}/.google_authenticator" ]]; then
		die "${CATEGORY}: refusing to enable — ${HOME}/.google_authenticator missing (run google-authenticator first)"
	fi
	sudo sshd -t
	sudo systemctl enable --now ssh.service
	log_success "${CATEGORY}: ssh.service enabled on port 7747"
}

cmd_disable() {
	if systemctl is-active ssh.service >/dev/null 2>&1; then
		sudo systemctl disable --now ssh.service
		log_success "${CATEGORY}: ssh.service disabled"
	else
		log_debug "${CATEGORY}: ssh.service already inactive"
	fi
}

cmd_status() {
	log_step "${CATEGORY}: status"
	if sudo test -r "${DEST}"; then
		printf 'deployed    %s\n' "${DEST}"
	else
		printf 'missing     %s\n' "${DEST}"
	fi
	if systemctl is-active ssh.service >/dev/null 2>&1; then
		printf 'active      ssh.service (port 7747)\n'
	else
		printf 'inactive    ssh.service\n'
	fi
}

# `link` / `unlink` are no-ops for system-level categories.
cmd_link()   { log_debug "${CATEGORY}: no symlinks managed by this category"; }
cmd_unlink() { log_debug "${CATEGORY}: no symlinks managed by this category"; }

main() {
	local subcmd=${1:-}
	case ${subcmd} in
		install|enable|disable|link|unlink|status)
			"cmd_${subcmd}"
			;;
		"")
			die "usage: $0 {install|enable|disable|link|unlink|status}"
			;;
		*)
			die "unknown subcommand: ${subcmd}"
			;;
	esac
}

main "$@"
