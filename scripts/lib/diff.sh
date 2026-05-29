# shellcheck shell=bash
#
# Set-difference helpers for the capture/diff harness. Source from any script:
#   source "${DOTFILES_ROOT}/scripts/lib/log.sh"
#   source "${DOTFILES_ROOT}/scripts/lib/diff.sh"

# diff_sets LABEL REPO_FILE SYSTEM_FILE
#   Both files contain one identifier per line. Prints two sections:
#     - "in repo only"   — declared, not present on system (missing install)
#     - "on system only" — present, not declared (manual install — fold into
#                          repo manifest if it's intentional, uninstall if not)
#   Returns 0 always; this is informational output, not a pass/fail signal.
diff_sets() {
	local label=$1 repo=$2 system=$3
	local in_repo_only on_system_only
	in_repo_only=$(comm -23 <(sort -u "${repo}") <(sort -u "${system}") || true)
	on_system_only=$(comm -13 <(sort -u "${repo}") <(sort -u "${system}") || true)

	printf '\n=== %s ===\n' "${label}"

	if [[ -z ${in_repo_only} && -z ${on_system_only} ]]; then
		printf '  (in sync)\n'
		return 0
	fi

	if [[ -n ${in_repo_only} ]]; then
		printf '\n  in repo only (declared, not installed):\n'
		printf '    %s\n' ${in_repo_only}
	fi

	if [[ -n ${on_system_only} ]]; then
		printf '\n  on system only (manually installed, not in repo):\n'
		printf '    %s\n' ${on_system_only}
	fi
}
