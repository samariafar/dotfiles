# shellcheck shell=bash
#
# Package-manager wrappers (apt, snap, flatpak). Idempotent: skip work when the
# requested package is already present.
#
# Source from any script:
#   source "${DOTFILES_ROOT}/scripts/lib/log.sh"
#   source "${DOTFILES_ROOT}/scripts/lib/pkg.sh"

# --- apt -----------------------------------------------------------------------

pkg_apt_installed() {
	local name=$1
	dpkg-query -W -f='${Status}\n' "${name}" 2>/dev/null | grep -q 'install ok installed'
}

pkg_apt_update() {
	log_step "apt update"
	sudo apt-get update -qq
}

# pkg_apt_install PKG...
#   Installs only packages not already present. No-op if everything is there.
pkg_apt_install() {
	local missing=()
	local name
	for name in "$@"; do
		if pkg_apt_installed "${name}"; then
			log_debug "apt: already installed: ${name}"
		else
			missing+=("${name}")
		fi
	done
	if (( ${#missing[@]} == 0 )); then
		return 0
	fi
	log_step "apt install: ${missing[*]}"
	sudo apt-get install -y --no-install-recommends "${missing[@]}"
}

# --- snap ----------------------------------------------------------------------

pkg_snap_installed() {
	local name=$1
	snap list "${name}" >/dev/null 2>&1
}

# pkg_snap_install NAME [extra args...]
#   Pass extra flags like --classic, --edge inline after NAME.
pkg_snap_install() {
	local name=$1
	shift
	if pkg_snap_installed "${name}"; then
		log_debug "snap: already installed: ${name}"
		return 0
	fi
	log_step "snap install: ${name} $*"
	sudo snap install "${name}" "$@"
}

# --- flatpak -------------------------------------------------------------------

pkg_flatpak_installed() {
	local ref=$1
	flatpak info "${ref}" >/dev/null 2>&1
}

# pkg_flatpak_install REF [REMOTE]
#   REMOTE defaults to flathub. Installs system-wide via sudo.
pkg_flatpak_install() {
	local ref=$1 remote=${2:-flathub}
	if pkg_flatpak_installed "${ref}"; then
		log_debug "flatpak: already installed: ${ref}"
		return 0
	fi
	log_step "flatpak install: ${ref} (from ${remote})"
	sudo flatpak install -y "${remote}" "${ref}"
}
