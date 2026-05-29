#!/usr/bin/env bash
#
# Capture / diff: enabled GNOME Shell extensions.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/diff.sh
source "${DOTFILES_ROOT}/scripts/lib/diff.sh"
# shellcheck source=../lib/yaml.sh
source "${DOTFILES_ROOT}/scripts/lib/yaml.sh"

CATEGORY=gnome-extensions
VAR_CAPTURED="${DOTFILES_ROOT}/var/captured"
SYSTEM_FILE="${VAR_CAPTURED}/gnome-extensions.txt"
MANIFEST="${DOTFILES_ROOT}/data/extensions/gnome.yaml"

cmd_capture() {
	if ! command -v gnome-extensions >/dev/null 2>&1; then
		log_warn "${CATEGORY}: gnome-extensions CLI not found — likely not running GNOME"
		return 0
	fi
	mkdir -p "${VAR_CAPTURED}"
	log_step "${CATEGORY}: capture → ${SYSTEM_FILE}"
	gnome-extensions list --enabled 2>/dev/null | sort -u > "${SYSTEM_FILE}"
	log_info "${CATEGORY}: $(wc -l < "${SYSTEM_FILE}") enabled extensions"
}

cmd_diff() {
	yaml_require
	if [[ ! -r ${SYSTEM_FILE} ]]; then
		log_warn "${CATEGORY}: no capture yet — run 'make capture' first"
		return 0
	fi
	local repo_list
	repo_list=$(mktemp -t dotfiles-gnome-ext-repo.XXXXXX)
	yq -r '.extensions[].uuid' "${MANIFEST}" | sort -u > "${repo_list}"
	diff_sets "gnome-extensions (enabled)" "${repo_list}" "${SYSTEM_FILE}"
	rm -f "${repo_list}"
}

main() {
	local subcmd=${1:-}
	case ${subcmd} in
		capture|diff)
			"cmd_${subcmd}"
			;;
		"")
			die "usage: $0 {capture|diff}"
			;;
		*)
			die "unknown subcommand: ${subcmd}"
			;;
	esac
}

main "$@"
