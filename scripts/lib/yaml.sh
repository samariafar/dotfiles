# shellcheck shell=bash
#
# Thin wrapper around yq-go (Mike Farah's yq) for reading the YAML manifests
# under data/. Source from any script:
#   source "${DOTFILES_ROOT}/scripts/lib/log.sh"
#   source "${DOTFILES_ROOT}/scripts/lib/yaml.sh"

# Guard: ensure yq-go is on PATH. Called once near the top of any script that
# reads manifests.
yaml_require() {
	if ! command -v yq >/dev/null 2>&1; then
		die "yq (Mike Farah's go binary) is required — install via 'sudo snap install yq' or apt"
	fi
}

# yaml_query FILE EXPR
#   Run a yq expression against FILE and print the result to stdout. Fails fast
#   on a missing file rather than yielding an empty result that callers might
#   silently treat as success. When the expression yields a sequence, yq emits
#   one element per line — feed straight into `mapfile -t` or `while read`.
yaml_query() {
	local file=$1 expr=$2
	[[ -r ${file} ]] || die "yaml_query: file not readable: ${file}"
	yq -r "${expr}" "${file}"
}
