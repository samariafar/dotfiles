#!/usr/bin/env bash
#
# Category: dns
#
# Encrypted DNS via dnscrypt-proxy (Quad9 filtered primary, Cloudflare
# fallback). Disables systemd-resolved + tells NetworkManager not to write
# /etc/resolv.conf, so the local dnscrypt-proxy on 127.0.0.1:53 is the
# authoritative resolver.
#
# IMPORTANT: this changes the system's DNS path. If something goes wrong
# (firewall blocks 853/443, Quad9 unreachable), DNS goes silent until the
# service is stopped: `sudo systemctl stop dnscrypt-proxy.service`. Run on a
# host with sudo access to recover.

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

CATEGORY=dns

DNSCRYPT_SRC="${DOTFILES_ROOT}/system/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
DNSCRYPT_DEST="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
NM_SRC="${DOTFILES_ROOT}/system/etc/NetworkManager/conf.d/99-dotfiles-dns.conf"
NM_DEST="/etc/NetworkManager/conf.d/99-dotfiles-dns.conf"

cmd_install() {
	system_require_ubuntu || return 0
	log_step "${CATEGORY}: install"
	pkg_apt_install dnscrypt-proxy
	system_install "${DNSCRYPT_SRC}" "${DNSCRYPT_DEST}" 0644
	system_install "${NM_SRC}" "${NM_DEST}" 0644

	log_step "${CATEGORY}: disable systemd-resolved (dnscrypt-proxy owns DNS now)"
	if systemctl is-active systemd-resolved.service >/dev/null 2>&1; then
		sudo systemctl disable --now systemd-resolved.service
	fi
	# /etc/resolv.conf is normally a symlink into stub-resolv.conf; replace
	# with a static file pointing at the local dnscrypt-proxy listener.
	if sudo test -L /etc/resolv.conf || ! sudo grep -q '^nameserver 127\.0\.0\.1$' /etc/resolv.conf 2>/dev/null; then
		sudo rm -f /etc/resolv.conf
		printf 'nameserver 127.0.0.1\nnameserver ::1\n' | sudo tee /etc/resolv.conf >/dev/null
	fi

	log_step "${CATEGORY}: enable dnscrypt-proxy + reload NetworkManager"
	sudo systemctl enable --now dnscrypt-proxy.service
	sudo systemctl reload-or-restart NetworkManager.service
}

cmd_status() {
	log_step "${CATEGORY}: status"
	if sudo test -r "${DNSCRYPT_DEST}"; then
		printf 'deployed    %s\n' "${DNSCRYPT_DEST}"
	else
		printf 'missing     %s\n' "${DNSCRYPT_DEST}"
	fi
	if sudo test -r "${NM_DEST}"; then
		printf 'deployed    %s\n' "${NM_DEST}"
	else
		printf 'missing     %s\n' "${NM_DEST}"
	fi
	if systemctl is-active dnscrypt-proxy.service >/dev/null 2>&1; then
		printf 'active      dnscrypt-proxy.service\n'
	else
		printf 'inactive    dnscrypt-proxy.service\n'
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
