#!/usr/bin/env bash
#
# Capture / diff: installed Firefox extensions.
#
# Reads extensions.json from every Firefox profile under the snap path
# (Ubuntu 26 default) and the deb path (~/.mozilla/firefox/). Emits the union
# of installed extension ids — duplicates collapse via `sort -u`.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/diff.sh
source "${DOTFILES_ROOT}/scripts/lib/diff.sh"
# shellcheck source=../lib/yaml.sh
source "${DOTFILES_ROOT}/scripts/lib/yaml.sh"

CATEGORY=firefox
VAR_CAPTURED="${DOTFILES_ROOT}/var/captured"
SYSTEM_FILE="${VAR_CAPTURED}/firefox-extensions.txt"
MANIFEST="${DOTFILES_ROOT}/data/extensions/firefox.yaml"

discover_profiles() {
	local roots=(
		"${HOME}/snap/firefox/common/.mozilla/firefox"
		"${HOME}/.mozilla/firefox"
	)
	local root profile
	for root in "${roots[@]}"; do
		[[ -d ${root} ]] || continue
		for profile in "${root}"/*.default*/; do
			[[ -d ${profile} ]] || continue
			printf '%s\n' "${profile%/}"
		done
	done
}

cmd_capture() {
	if ! command -v jq >/dev/null 2>&1; then
		log_warn "${CATEGORY}: jq required to parse extensions.json — skipping"
		return 0
	fi
	mkdir -p "${VAR_CAPTURED}"
	log_step "${CATEGORY}: capture → ${SYSTEM_FILE}"
	local profile ext_file
	: > "${SYSTEM_FILE}"
	while read -r profile; do
		[[ -n ${profile} ]] || continue
		ext_file="${profile}/extensions.json"
		[[ -r ${ext_file} ]] || continue
		# Skip Firefox system / built-in addons; user-installed ones have
		# location = "app-profile" or "app-temporary". Extensions installed via
		# enterprise policy show up as "app-system-defaults" — include those too
		# because that's exactly what data/extensions/firefox.yaml manages.
		jq -r '.addons[] | select(.location | test("app-profile|app-temporary|app-system-defaults")) | .id' \
			"${ext_file}" 2>/dev/null >> "${SYSTEM_FILE}" || true
	done < <(discover_profiles)
	sort -u -o "${SYSTEM_FILE}" "${SYSTEM_FILE}"
	log_info "${CATEGORY}: $(wc -l < "${SYSTEM_FILE}") installed extensions"
}

cmd_diff() {
	yaml_require
	if [[ ! -r ${SYSTEM_FILE} ]]; then
		log_warn "${CATEGORY}: no capture yet — run 'make capture' first"
		return 0
	fi
	local repo_list
	repo_list=$(mktemp -t dotfiles-firefox-repo.XXXXXX)
	yq -r '.extensions[].id' "${MANIFEST}" | sort -u > "${repo_list}"
	diff_sets "firefox-extensions" "${repo_list}" "${SYSTEM_FILE}"
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
