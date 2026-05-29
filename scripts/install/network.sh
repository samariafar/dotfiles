#!/usr/bin/env bash
#
# Category: network
#
# Render NetworkManager WiFi profiles from sops-encrypted secrets.yaml into
# /etc/NetworkManager/system-connections/. Pure no-op when secrets.yaml has
# no `wifi:` section, or when sops/age aren't available. Otherwise one
# .nmconnection file per declared profile, mode 0600, root-owned.
#
# secrets.yaml schema (optional — omit the whole `wifi:` section to skip):
#
#   wifi:
#     home:
#       ssid: "your-ssid"
#       psk:  "your-psk"
#     office:
#       ssid: "another-ssid"
#       psk:  "another-psk"

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/os.sh
source "${DOTFILES_ROOT}/scripts/lib/os.sh"
# shellcheck source=../lib/system.sh
source "${DOTFILES_ROOT}/scripts/lib/system.sh"

CATEGORY=network

SECRETS_FILE="${DOTFILES_ROOT}/secrets.yaml"
NM_DIR="/etc/NetworkManager/system-connections"

preflight() {
	if [[ ! -r ${SECRETS_FILE} ]]; then
		log_warn "${CATEGORY}: ${SECRETS_FILE} not found — skipping"
		return 1
	fi
	local tool
	for tool in sops yq; do
		if ! command -v "${tool}" >/dev/null 2>&1; then
			log_warn "${CATEGORY}: ${tool} not on PATH — skipping"
			return 1
		fi
	done
	local keyfile=${SOPS_AGE_KEY_FILE:-${HOME}/Vault/Keys/Sam/age-private.key}
	if [[ ! -r ${keyfile} ]]; then
		log_warn "${CATEGORY}: age key not readable at ${keyfile} — skipping"
		return 1
	fi
	export SOPS_AGE_KEY_FILE="${keyfile}"
}

# render_nmconnection NAME SSID PSK
#   Emits a NetworkManager keyfile (INI format). Auto-connect on, infrastructure
#   mode, WPA-PSK security. Writes to stdout.
render_nmconnection() {
	local name=$1 ssid=$2 psk=$3
	cat <<-EOF
		[connection]
		id=${name}
		type=wifi
		autoconnect=true
		uuid=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)

		[wifi]
		mode=infrastructure
		ssid=${ssid}

		[wifi-security]
		key-mgmt=wpa-psk
		psk=${psk}

		[ipv4]
		method=auto

		[ipv6]
		method=auto
	EOF
}

cmd_install() {
	system_require_ubuntu || return 0
	if ! preflight; then
		return 0
	fi

	# Decrypt once into a tmpfile, then read each declared wifi profile.
	local decrypted
	decrypted=$(mktemp -t dotfiles-secrets.XXXXXX.yaml)
	chmod 600 "${decrypted}"
	# shellcheck disable=SC2064
	trap "rm -f '${decrypted}'" RETURN
	sops -d "${SECRETS_FILE}" > "${decrypted}"

	# Bail cleanly if no wifi: section.
	if [[ $(yq -r '.wifi // {} | keys | length' "${decrypted}") -eq 0 ]]; then
		log_info "${CATEGORY}: secrets.yaml has no wifi: section — nothing to render"
		return 0
	fi

	log_step "${CATEGORY}: render NM profiles"
	local name ssid psk tmp dest
	while read -r name; do
		[[ -z ${name} ]] && continue
		ssid=$(yq -r ".wifi.${name}.ssid" "${decrypted}")
		psk=$(yq -r ".wifi.${name}.psk" "${decrypted}")
		[[ -z ${ssid} || ${ssid} == null ]] && { log_warn "${CATEGORY}: wifi.${name}.ssid missing"; continue; }
		[[ -z ${psk} || ${psk} == null ]] && { log_warn "${CATEGORY}: wifi.${name}.psk missing"; continue; }

		tmp=$(mktemp -t dotfiles-nm.XXXXXX)
		chmod 600 "${tmp}"
		render_nmconnection "${name}" "${ssid}" "${psk}" > "${tmp}"
		dest="${NM_DIR}/${name}.nmconnection"
		sudo install -Dm600 -o root -g root "${tmp}" "${dest}"
		rm -f "${tmp}"
		log_success "${CATEGORY}: wrote ${dest}"
	done < <(yq -r '.wifi | keys[]' "${decrypted}")

	log_step "${CATEGORY}: reload NetworkManager connections"
	sudo nmcli connection reload
}

cmd_status() {
	log_step "${CATEGORY}: status"
	if ! sudo test -d "${NM_DIR}"; then
		printf 'missing     %s\n' "${NM_DIR}"
		return 0
	fi
	if ! preflight; then
		return 0
	fi
	local decrypted name
	decrypted=$(mktemp -t dotfiles-secrets.XXXXXX.yaml)
	chmod 600 "${decrypted}"
	# shellcheck disable=SC2064
	trap "rm -f '${decrypted}'" RETURN
	sops -d "${SECRETS_FILE}" > "${decrypted}"
	if [[ $(yq -r '.wifi // {} | keys | length' "${decrypted}") -eq 0 ]]; then
		printf 'unconfigured no wifi: section in secrets.yaml\n'
		return 0
	fi
	while read -r name; do
		[[ -z ${name} ]] && continue
		if sudo test -r "${NM_DIR}/${name}.nmconnection"; then
			printf 'deployed    %s/%s.nmconnection\n' "${NM_DIR}" "${name}"
		else
			printf 'missing     %s/%s.nmconnection\n' "${NM_DIR}" "${name}"
		fi
	done < <(yq -r '.wifi | keys[]' "${decrypted}")
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
