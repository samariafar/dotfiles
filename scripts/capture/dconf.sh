#!/usr/bin/env bash
#
# Capture / diff: GNOME dconf settings.
#
#   capture: full `dconf dump /` snapshot, then a filtered view that strips
#            schemas known to churn under normal use (window state, recent
#            files, app-runtime caches). The filtered view is what `diff`
#            compares against the repo's gnome/dconf/*.ini snippets.
#
#   diff:    a fuzzy structural diff — concatenates the filtered system
#            snapshot with a concatenation of all repo dconf snippets, then
#            shows added / removed / changed keys. Will surface real drift
#            without drowning in dconf's normal noise.
#
# This is the noisy one — expect false positives at first. Add patterns to
# NOISE_PATTERNS to silence them; the goal is a signal-to-noise ratio that
# makes the diff actually scannable, not a perfect reconstruction.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"

CATEGORY=dconf
VAR_CAPTURED="${DOTFILES_ROOT}/var/captured"
RAW_FILE="${VAR_CAPTURED}/dconf-raw.ini"
FILTERED_FILE="${VAR_CAPTURED}/dconf.ini"
DCONF_DIR="${DOTFILES_ROOT}/gnome/dconf"

# Header patterns of dconf sections to strip from the filtered snapshot. Each
# pattern is a POSIX ERE matched against the `[section/path]` line; matching
# sections are dropped entirely (header + all following key=value lines until
# the next `[` header or EOF).
NOISE_PATTERNS=(
	# Window manager runtime state (positions, sizes, last-focused workspace).
	'^\[org/gnome/mutter/wayland/'
	# Application-specific recent-file / window-state churn.
	'^\[org/gnome/nautilus/window-state'
	'^\[org/gtk/gtk4/settings/file-chooser\]'
	'^\[org/gtk/settings/file-chooser\]'
	# Per-app notification timestamps + read state.
	'^\[org/gnome/desktop/notifications/application/'
	# Privacy logs and accessed-files lists.
	'^\[org/gnome/desktop/privacy/'
	# Online-account session tokens (never want these in repo).
	'^\[org/gnome/online-accounts'
	# Evolution caches.
	'^\[org/gnome/evolution-data-server/'
)

cmd_capture() {
	if ! command -v dconf >/dev/null 2>&1; then
		log_warn "${CATEGORY}: dconf CLI not available — likely not running GNOME"
		return 0
	fi
	mkdir -p "${VAR_CAPTURED}"
	log_step "${CATEGORY}: capture → ${RAW_FILE}"
	dconf dump / > "${RAW_FILE}"

	log_step "${CATEGORY}: filter → ${FILTERED_FILE}"
	# Section-aware bash filter. Tracks the current section header; when it
	# matches any NOISE_PATTERN (interpreted by bash's =~), enters "skip" mode
	# until the next header. Pure bash avoids the awk-vs-bash regex-escaping
	# tangle that broke an earlier awk-based version.
	local skip=0 line pattern
	: > "${FILTERED_FILE}"
	while IFS= read -r line || [[ -n ${line} ]]; do
		if [[ ${line} == "["* ]]; then
			skip=0
			for pattern in "${NOISE_PATTERNS[@]}"; do
				if [[ ${line} =~ ${pattern} ]]; then
					skip=1
					break
				fi
			done
		fi
		(( skip == 0 )) && printf '%s\n' "${line}" >> "${FILTERED_FILE}"
	done < "${RAW_FILE}"
	log_info "${CATEGORY}: $(wc -l < "${FILTERED_FILE}") lines after filter ($(wc -l < "${RAW_FILE}") raw)"
}

cmd_diff() {
	if [[ ! -r ${FILTERED_FILE} ]]; then
		log_warn "${CATEGORY}: no capture yet — run 'make capture' first"
		return 0
	fi
	local repo_ini
	repo_ini=$(mktemp -t dotfiles-dconf-repo.XXXXXX.ini)
	# Concatenate every repo dconf snippet into one file in the same INI shape
	# as `dconf dump /` for a straight diff.
	cat "${DCONF_DIR}"/*.ini > "${repo_ini}" 2>/dev/null || true
	printf '\n=== dconf (filtered system) vs gnome/dconf/*.ini ===\n\n'
	# Use diff with --color=auto so terminals get nice output; if `diff` lacks
	# --color (old GNU diff), drop it.
	if diff --color=auto -u "${repo_ini}" "${FILTERED_FILE}" 2>/dev/null; then
		printf '  (in sync — modulo noise filter)\n'
	fi
	rm -f "${repo_ini}"
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
