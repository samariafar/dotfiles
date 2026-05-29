#!/usr/bin/env bash
#
# Capture / diff: manually-installed apt packages.
#
#   capture: writes ${VAR_CAPTURED}/apt.txt — `apt-mark showmanual`, sorted.
#            (showmanual filters to packages explicitly installed by the user,
#             excluding transitively-pulled dependencies. Without that filter
#             the list is 1500+ packages of noise.)
#   diff:    compares ${VAR_CAPTURED}/apt.txt against data/packages.yaml's
#            `apt:` section and prints set differences.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/diff.sh
source "${DOTFILES_ROOT}/scripts/lib/diff.sh"
# shellcheck source=../lib/yaml.sh
source "${DOTFILES_ROOT}/scripts/lib/yaml.sh"

CATEGORY=apt
VAR_CAPTURED="${DOTFILES_ROOT}/var/captured"
SYSTEM_FILE="${VAR_CAPTURED}/apt.txt"
MANIFEST="${DOTFILES_ROOT}/data/packages.yaml"

cmd_capture() {
	if ! command -v apt-mark >/dev/null 2>&1; then
		log_warn "${CATEGORY}: apt-mark not available — likely not on a Debian-derived system"
		return 0
	fi
	mkdir -p "${VAR_CAPTURED}"
	log_step "${CATEGORY}: capture → ${SYSTEM_FILE}"
	apt-mark showmanual | sort -u > "${SYSTEM_FILE}"
	log_info "${CATEGORY}: $(wc -l < "${SYSTEM_FILE}") manually-installed packages"
}

cmd_diff() {
	yaml_require
	if [[ ! -r ${SYSTEM_FILE} ]]; then
		log_warn "${CATEGORY}: no capture yet — run 'make capture' first"
		return 0
	fi
	local repo_list
	repo_list=$(mktemp -t dotfiles-apt-repo.XXXXXX)
	# Each apt entry is either a bare string (package name) or a mapping
	# with .name — yq's `(type == "object")` branch handles both.
	yq -r '.apt[] | (if type == "object" then .name else . end)' "${MANIFEST}" \
		| sort -u > "${repo_list}"
	diff_sets "apt (manually installed)" "${repo_list}" "${SYSTEM_FILE}"
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
