#!/usr/bin/env bash
#
# Capture / diff: installed snap packages.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/diff.sh
source "${DOTFILES_ROOT}/scripts/lib/diff.sh"
# shellcheck source=../lib/yaml.sh
source "${DOTFILES_ROOT}/scripts/lib/yaml.sh"

CATEGORY=snap
VAR_CAPTURED="${DOTFILES_ROOT}/var/captured"
SYSTEM_FILE="${VAR_CAPTURED}/snap.txt"
MANIFEST="${DOTFILES_ROOT}/data/packages.yaml"

cmd_capture() {
	if ! command -v snap >/dev/null 2>&1; then
		log_warn "${CATEGORY}: snap not available — nothing to capture"
		return 0
	fi
	mkdir -p "${VAR_CAPTURED}"
	log_step "${CATEGORY}: capture → ${SYSTEM_FILE}"
	# snap list emits a header line + one row per installed snap. The first
	# column is the snap name; awk strips the header.
	snap list --unicode=never 2>/dev/null \
		| awk 'NR>1 {print $1}' \
		| sort -u > "${SYSTEM_FILE}"
	log_info "${CATEGORY}: $(wc -l < "${SYSTEM_FILE}") installed snaps"
}

cmd_diff() {
	yaml_require
	if [[ ! -r ${SYSTEM_FILE} ]]; then
		log_warn "${CATEGORY}: no capture yet — run 'make capture' first"
		return 0
	fi
	local repo_list
	repo_list=$(mktemp -t dotfiles-snap-repo.XXXXXX)
	yq -r '.snap[] | (if type == "object" then .name else . end)' "${MANIFEST}" \
		| sort -u > "${repo_list}"
	diff_sets "snap" "${repo_list}" "${SYSTEM_FILE}"
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
