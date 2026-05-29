#!/usr/bin/env bash
#
# Category: gnome
#
# Applies the dconf snippets under gnome/dconf/ and installs the GNOME Shell
# extensions listed in data/extensions/gnome.yaml. Unlike other categories this
# one does not symlink configuration files — dconf is a key/value store, not
# files on disk — so `link` and `unlink` are no-ops here.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/os.sh
source "${DOTFILES_ROOT}/scripts/lib/os.sh"
# shellcheck source=../lib/pkg.sh
source "${DOTFILES_ROOT}/scripts/lib/pkg.sh"
# shellcheck source=../lib/yaml.sh
source "${DOTFILES_ROOT}/scripts/lib/yaml.sh"

CATEGORY=gnome

DCONF_DIR="${DOTFILES_ROOT}/gnome/dconf"
EXTENSIONS_MANIFEST="${DOTFILES_ROOT}/data/extensions/gnome.yaml"

# --- helpers ------------------------------------------------------------------

ensure_gext() {
	# gnome-extensions-cli is the no-frills install/uninstall tool for shell
	# extensions. apt's `gnome-shell-extension-manager` is the GUI app — useful
	# but interactive. We install gext into a pipx venv so it stays isolated
	# from the system Python.
	if command -v gext >/dev/null 2>&1; then
		log_debug "gext already on PATH"
		return
	fi
	pkg_apt_install pipx
	pipx install gnome-extensions-cli
	# pipx puts shims under ~/.local/bin — already on PATH via ~/.profile.
	hash -r
}

apply_dconf() {
	local ini
	for ini in "${DCONF_DIR}"/*.ini; do
		[[ -f ${ini} ]] || continue
		log_info "applying $(basename "${ini}")"
		dconf load / < "${ini}"
	done
}

install_extensions() {
	yaml_require
	local uuid
	while read -r uuid; do
		[[ -z ${uuid} ]] && continue
		if gnome-extensions list 2>/dev/null | grep -qx "${uuid}"; then
			log_debug "extension already present: ${uuid}"
			continue
		fi
		log_step "installing extension: ${uuid}"
		# gext exits non-zero when the extension can't be found for the
		# running shell version. Don't abort the whole batch — log and move on.
		if ! gext install "${uuid}"; then
			log_warn "could not install ${uuid} — install manually via gnome-extension-manager"
		fi
	done < <(yaml_query "${EXTENSIONS_MANIFEST}" '.extensions[].uuid')
}

# --- commands -----------------------------------------------------------------

cmd_install() {
	require_ubuntu
	log_step "${CATEGORY}: install"
	pkg_apt_install \
		dconf-cli \
		dconf-editor \
		gnome-shell-extension-manager \
		gnome-tweaks
	ensure_gext
	apply_dconf
	install_extensions
	log_warn "log out and back in (or restart GNOME Shell) for newly-installed extensions to load"
}

cmd_link() {
	log_debug "${CATEGORY}: no symlinks managed by this category"
}

cmd_unlink() {
	log_debug "${CATEGORY}: no symlinks managed by this category"
}

cmd_status() {
	log_step "${CATEGORY}: status"
	if ! command -v gnome-extensions >/dev/null 2>&1; then
		log_warn "gnome-extensions CLI not found — likely not running GNOME"
		return 0
	fi
	yaml_require
	local uuid state
	while read -r uuid; do
		[[ -z ${uuid} ]] && continue
		if gnome-extensions list --enabled 2>/dev/null | grep -qx "${uuid}"; then
			state="enabled"
		elif gnome-extensions list 2>/dev/null | grep -qx "${uuid}"; then
			state="installed-but-disabled"
		else
			state="missing"
		fi
		printf '%-25s %s\n' "${state}" "${uuid}"
	done < <(yaml_query "${EXTENSIONS_MANIFEST}" '.extensions[].uuid')
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
