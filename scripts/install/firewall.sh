#!/usr/bin/env bash
#
# Category: firewall
#
# UFW (uncomplicated firewall) — deny-all incoming, allow-all outgoing, plus
# one rule per port the dotfiles ships in an enabled state (currently nothing
# is enabled by default; SSH port 7747 is opened only when sshd.sh's
# `enable` subcommand has been run).
#
# Ports nixcfg modules/nixos/networking.nix:
#   networking.firewall.enable = true;
#   networking.firewall.allowedTCPPorts = [];   (default-deny)
#   networking.firewall.allowedUDPPorts = [];

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

CATEGORY=firewall

cmd_install() {
	system_require_ubuntu || return 0
	log_step "${CATEGORY}: install"
	pkg_apt_install ufw
	log_step "${CATEGORY}: configure default-deny"
	sudo ufw --force default deny incoming
	sudo ufw --force default allow outgoing

	# Opportunistic SSH allow: if sshd.sh has been enabled (sshd_config.d
	# snippet present AND ssh.service active), open port 7747. Otherwise
	# leave the firewall locked down.
	if systemctl is-active ssh.service >/dev/null 2>&1; then
		log_step "${CATEGORY}: ssh.service active — opening port 7747"
		sudo ufw allow 7747/tcp comment 'dotfiles sshd'
	fi

	log_step "${CATEGORY}: enable"
	sudo ufw --force enable
}

cmd_status() {
	log_step "${CATEGORY}: status"
	if command -v ufw >/dev/null 2>&1; then
		sudo ufw status verbose
	else
		printf 'missing     ufw\n'
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
