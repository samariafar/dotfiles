#!/usr/bin/env bash
#
# Category: firefox
#
# Composes firefox/policies.template.json with the extensions listed in
# data/extensions/firefox.yaml to produce the final policies.json, installs it
# (system-wide, sudo) under /etc/firefox/policies/, and symlinks
# firefox/userChrome.css into every detected Firefox profile (snap and deb).

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/os.sh
source "${DOTFILES_ROOT}/scripts/lib/os.sh"
# shellcheck source=../lib/link.sh
source "${DOTFILES_ROOT}/scripts/lib/link.sh"
# shellcheck source=../lib/pkg.sh
source "${DOTFILES_ROOT}/scripts/lib/pkg.sh"
# shellcheck source=../lib/yaml.sh
source "${DOTFILES_ROOT}/scripts/lib/yaml.sh"

CATEGORY=firefox

POLICIES_TEMPLATE="${DOTFILES_ROOT}/firefox/policies.template.json"
USERCHROME_SRC="${DOTFILES_ROOT}/firefox/userChrome.css"
EXTENSIONS_MANIFEST="${DOTFILES_ROOT}/data/extensions/firefox.yaml"
POLICIES_DEST=/etc/firefox/policies/policies.json

# --- profile discovery --------------------------------------------------------

# Discover Firefox profile directories. Ubuntu 26 ships Firefox as a snap;
# the profile lives under ~/snap/firefox/common/.mozilla/firefox/. A user who
# replaces it with the official .deb (or runs both) gets ~/.mozilla/firefox/.
# We support both — emit every profile dir found, one per line.
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

# --- policies.json composition -----------------------------------------------

# Build the final policies.json by merging template + extensions manifest.
# Each extension becomes an ExtensionSettings entry with installation_mode,
# install_url, and a default_area, with optional overrides from `.options`.
build_policies_json() {
	yaml_require
	command -v jq >/dev/null 2>&1 || die "jq is required to build policies.json"

	# yq-go's object-construction syntax with computed keys is fussy; pass the
	# manifest through yq → jq so jq handles the merge in its native dialect.
	local ext_settings
	ext_settings=$(
		yq -o=json . "${EXTENSIONS_MANIFEST}" \
			| jq '.extensions
			      | map({
			          (.id): (
			            { installation_mode: "force_installed",
			              install_url: .url,
			              default_area: "menupanel"
			            } + (.options // {})
			          )
			        })
			      | add'
	)

	jq --argjson ext "${ext_settings}" \
		'.policies.ExtensionSettings = ((.policies.ExtensionSettings // {}) + $ext)' \
		"${POLICIES_TEMPLATE}"
}

# --- commands -----------------------------------------------------------------

cmd_install() {
	require_ubuntu
	log_step "${CATEGORY}: install"

	# Ensure Firefox itself is present. The snap is Ubuntu 26's default
	# delivery; the apt package is a transitional wrapper that installs the
	# snap on first run, so either works.
	pkg_apt_install firefox

	# Compose policies.json and drop it system-wide (Firefox picks it up
	# regardless of snap vs deb).
	log_step "${CATEGORY}: assembling policies.json"
	local tmp
	tmp=$(mktemp -t dotfiles-firefox-policies.XXXXXX.json)
	# shellcheck disable=SC2064
	trap "rm -f '${tmp}'" RETURN
	build_policies_json > "${tmp}"

	log_step "${CATEGORY}: installing ${POLICIES_DEST} (sudo)"
	sudo install -Dm644 "${tmp}" "${POLICIES_DEST}"
}

cmd_link() {
	log_step "${CATEGORY}: link userChrome.css into each profile"
	local profile chrome_dir found=0
	while read -r profile; do
		[[ -n ${profile} ]] || continue
		found=1
		chrome_dir="${profile}/chrome"
		mkdir -p "${chrome_dir}"
		link_file "${USERCHROME_SRC}" "${chrome_dir}/userChrome.css"
	done < <(discover_profiles)

	if (( found == 0 )); then
		log_warn "no Firefox profile dirs found — run Firefox once to create one, then re-run 'make link'"
	fi
}

cmd_unlink() {
	log_step "${CATEGORY}: unlink"
	local profile
	while read -r profile; do
		[[ -n ${profile} ]] || continue
		unlink_file "${profile}/chrome/userChrome.css"
	done < <(discover_profiles)

	if [[ -f ${POLICIES_DEST} ]]; then
		if sudo test -L "${POLICIES_DEST}" -o -f "${POLICIES_DEST}"; then
			log_step "${CATEGORY}: removing ${POLICIES_DEST} (sudo)"
			sudo rm -f "${POLICIES_DEST}"
		fi
	fi
}

cmd_status() {
	log_step "${CATEGORY}: status"

	# policies.json — content match check vs the freshly-rendered template
	if [[ -r ${POLICIES_DEST} ]]; then
		local current desired
		current=$(sha256sum < "${POLICIES_DEST}" | awk '{print $1}')
		desired=$(build_policies_json | sha256sum | awk '{print $1}')
		if [[ ${current} == "${desired}" ]]; then
			printf 'in-sync     %s\n' "${POLICIES_DEST}"
		else
			printf 'drift       %s\n' "${POLICIES_DEST}"
		fi
	else
		printf 'missing     %s\n' "${POLICIES_DEST}"
	fi

	# userChrome.css per profile
	local profile dest
	while read -r profile; do
		[[ -n ${profile} ]] || continue
		dest="${profile}/chrome/userChrome.css"
		link_status "${dest}"
	done < <(discover_profiles)
}

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
