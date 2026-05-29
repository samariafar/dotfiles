#!/usr/bin/env bash
#
# Capture / diff: installed flatpak applications.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/diff.sh
source "${DOTFILES_ROOT}/scripts/lib/diff.sh"
# shellcheck source=../lib/yaml.sh
source "${DOTFILES_ROOT}/scripts/lib/yaml.sh"

CATEGORY=flatpak
VAR_CAPTURED="${DOTFILES_ROOT}/var/captured"
SYSTEM_FILE="${VAR_CAPTURED}/flatpak.txt"
MANIFEST="${DOTFILES_ROOT}/data/packages.yaml"

cmd_capture() {
	if ! command -v flatpak >/dev/null 2>&1; then
		log_warn "${CATEGORY}: flatpak not available — nothing to capture"
		return 0
	fi
	mkdir -p "${VAR_CAPTURED}"
	log_step "${CATEGORY}: capture → ${SYSTEM_FILE}"
	# --app filters out runtimes; --columns=application emits the app id only.
	flatpak list --app --columns=application 2>/dev/null \
		| sort -u > "${SYSTEM_FILE}"
	log_info "${CATEGORY}: $(wc -l < "${SYSTEM_FILE}") installed flatpaks"
}

cmd_diff() {
	yaml_require
	if [[ ! -r ${SYSTEM_FILE} ]]; then
		log_warn "${CATEGORY}: no capture yet — run 'make capture' first"
		return 0
	fi
	local repo_list
	repo_list=$(mktemp -t dotfiles-flatpak-repo.XXXXXX)
	yq -r '.flatpak[] | (if type == "object" then .name else . end)' "${MANIFEST}" \
		| sort -u > "${repo_list}"
	diff_sets "flatpak" "${repo_list}" "${SYSTEM_FILE}"
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
