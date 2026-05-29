#!/usr/bin/env bash
#
# Setup step: render sops-encrypted secrets into per-tool config files under
# the user's $HOME. Idempotent — re-running just rewrites the rendered files.
#
# Decryption requires:
#   - sops on PATH                    (apt: sops)
#   - age on PATH                     (apt: age)
#   - SOPS_AGE_KEY_FILE pointing at   (exported from home/.profile;
#     a readable age private key       default ~/Vault/Keys/Sam/age-private.key)
#
# When any of the above is missing the script logs a warning and exits 0 so
# `make apply` on a contributor machine without the user's key still succeeds
# — only the artifex-profile bits silently stay unconfigured.
#
# Rendered outputs (mode 0600, owned by the running user):
#   ~/.config/git/config-artifex          loaded via includeIf in ~/.config/git/config
#   ~/.config/git/profiles.d/artifex.env  sourced by ~/.config/git/profiles.sh

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"

SECRETS_FILE="${DOTFILES_ROOT}/secrets.yaml"

GIT_INCLUDE_DEST="${HOME}/.config/git/config-artifex"
GIT_PROFILES_DEST="${HOME}/.config/git/profiles.d/artifex.env"

# Public, not secret — the Vault path is a label, not the identity. Matches
# nixcfg's modules/home-manager/programs/cli/git.nix:18 verbatim.
ARTIFEX_SSH_KEY='~/Vault/Keys/Artifex/ssh-private.key'

CATEGORY=secrets

# Pre-flight: bail cleanly if we can't decrypt.
preflight() {
	if [[ ! -r ${SECRETS_FILE} ]]; then
		log_warn "${CATEGORY}: ${SECRETS_FILE} not found — nothing to render"
		return 1
	fi
	if ! command -v sops >/dev/null 2>&1; then
		log_warn "${CATEGORY}: sops not on PATH — skipping secret render (install: apt-get install sops)"
		return 1
	fi
	if ! command -v age >/dev/null 2>&1; then
		log_warn "${CATEGORY}: age not on PATH — skipping secret render (install: apt-get install age)"
		return 1
	fi
	local keyfile=${SOPS_AGE_KEY_FILE:-${HOME}/Vault/Keys/Sam/age-private.key}
	if [[ ! -r ${keyfile} ]]; then
		log_warn "${CATEGORY}: age key not readable at ${keyfile} — skipping secret render"
		log_info "${CATEGORY}: set SOPS_AGE_KEY_FILE to a readable key, or restore the Vault dir"
		return 1
	fi
	export SOPS_AGE_KEY_FILE="${keyfile}"
}

# yq_get YAML_PATH
#   Reads a scalar value from the decrypted secrets file. Caches the decrypted
#   blob in a single tmpfile (cleaned on exit) so we don't shell out to sops
#   per-field.
_DECRYPTED_TMP=
_cleanup_tmp() {
	[[ -n ${_DECRYPTED_TMP} && -f ${_DECRYPTED_TMP} ]] && rm -f "${_DECRYPTED_TMP}"
}
trap _cleanup_tmp EXIT

_decrypt_once() {
	if [[ -z ${_DECRYPTED_TMP} ]]; then
		_DECRYPTED_TMP=$(mktemp -t dotfiles-secrets.XXXXXX.yaml)
		chmod 600 "${_DECRYPTED_TMP}"
		sops -d "${SECRETS_FILE}" > "${_DECRYPTED_TMP}"
	fi
}

yq_get() {
	local path=$1
	_decrypt_once
	yq -r "${path}" "${_DECRYPTED_TMP}"
}

# render_atomic DEST CONTENT
#   Writes CONTENT to DEST atomically (write-then-rename) and sets mode 0600.
render_atomic() {
	local dest=$1 content=$2 tmp
	mkdir -p "$(dirname "${dest}")"
	tmp=$(mktemp "${dest}.XXXXXX")
	chmod 600 "${tmp}"
	printf '%s' "${content}" > "${tmp}"
	mv "${tmp}" "${dest}"
	log_success "rendered ${dest}"
}

render_git_artifex_config() {
	local name email signingkey
	name=$(yq_get '.profiles.artifex.name')
	email=$(yq_get '.profiles.artifex.email')
	signingkey=$(yq_get '.profiles.artifex.signingkey')

	# Mirrors the structure of the public ~/.config/git/config so the includeIf
	# from there layers cleanly. Tab-indented per the repo's git config style.
	local content
	content=$(printf '[user]\n\tname = %s\n\temail = %s\n\tsigningkey = %s\n\n[core]\n\tsshCommand = ssh -i %s\n' \
		"${name}" "${email}" "${signingkey}" "${ARTIFEX_SSH_KEY}")

	render_atomic "${GIT_INCLUDE_DEST}" "${content}"
}

render_git_artifex_profile_env() {
	local name email signingkey
	name=$(yq_get '.profiles.artifex.name')
	email=$(yq_get '.profiles.artifex.email')
	signingkey=$(yq_get '.profiles.artifex.signingkey')

	# Shell assignments sourced by ~/.config/git/profiles.sh, which merges them
	# into PROFILE_NAME / PROFILE_EMAIL / PROFILE_SIGNINGKEY. The SSH key path
	# is public and lives directly in profiles.sh, not here.
	local content
	content=$(printf "PROFILE_ARTIFEX_NAME=%q\nPROFILE_ARTIFEX_EMAIL=%q\nPROFILE_ARTIFEX_SIGNINGKEY=%q\n" \
		"${name}" "${email}" "${signingkey}")

	render_atomic "${GIT_PROFILES_DEST}" "${content}"
}

cmd_install() {
	if ! preflight; then
		return 0
	fi
	if ! command -v yq >/dev/null 2>&1; then
		log_warn "${CATEGORY}: yq not on PATH — skipping secret render (install: snap install yq)"
		return 0
	fi
	log_step "${CATEGORY}: render"
	render_git_artifex_config
	render_git_artifex_profile_env
}

# `unlink` removes the rendered files. Useful when reverting on a borrowed
# machine — leaves the encrypted source in place.
cmd_unlink() {
	log_step "${CATEGORY}: remove rendered files"
	local file
	for file in "${GIT_INCLUDE_DEST}" "${GIT_PROFILES_DEST}"; do
		if [[ -e ${file} ]]; then
			rm -f "${file}"
			log_success "removed ${file}"
		fi
	done
}

cmd_status() {
	log_step "${CATEGORY}: status"
	local file
	for file in "${GIT_INCLUDE_DEST}" "${GIT_PROFILES_DEST}"; do
		if [[ -f ${file} ]]; then
			printf 'rendered    %s\n' "${file}"
		else
			printf 'missing     %s\n' "${file}"
		fi
	done
}

main() {
	local subcmd=${1:-install}
	case ${subcmd} in
		install|unlink|status)
			"cmd_${subcmd}"
			;;
		*)
			die "usage: $0 {install|unlink|status}"
			;;
	esac
}

main "$@"
