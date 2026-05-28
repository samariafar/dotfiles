# shellcheck shell=bash
#
# Operating-system detection and guards. Source from any script:
#   source "${DOTFILES_ROOT}/scripts/lib/os.sh"

# Read a key from /etc/os-release without polluting the caller's environment.
_os_release_get() {
	local key=$1 value=
	if [[ -r /etc/os-release ]]; then
		value=$(
			# shellcheck disable=SC1091
			source /etc/os-release
			printf '%s' "${!key:-}"
		)
	fi
	printf '%s' "${value}"
}

os_id() {
	_os_release_get ID
}

os_id_like() {
	_os_release_get ID_LIKE
}

os_version_id() {
	_os_release_get VERSION_ID
}

os_codename() {
	_os_release_get VERSION_CODENAME
}

# True if running on Ubuntu specifically (not just any Debian derivative).
is_ubuntu() {
	[[ $(os_id) == ubuntu ]]
}

# True if running on Ubuntu LTS. Ubuntu LTS releases use even-numbered years
# (24.04, 26.04, ...).
is_ubuntu_lts() {
	is_ubuntu || return 1
	local version major
	version=$(os_version_id)
	major=${version%%.*}
	(( major % 2 == 0 ))
}

# Guard: abort unless the current host is Ubuntu.
require_ubuntu() {
	if ! is_ubuntu; then
		die "this script targets Ubuntu — detected '$(os_id)' instead"
	fi
}

# Guard: abort unless the current host is Ubuntu of at least the given version
# (numeric compare on the major release, e.g. 26 >= 24).
require_ubuntu_min() {
	require_ubuntu
	local want=$1 have major
	have=$(os_version_id)
	major=${have%%.*}
	if (( major < want )); then
		die "requires Ubuntu ${want}+ — detected Ubuntu ${have}"
	fi
}

# Guard: abort if running as root. Most install steps run as the user and
# escalate explicitly with sudo.
require_not_root() {
	if (( EUID == 0 )); then
		die "do not run this as root — invoke as your regular user; sudo is requested per-command"
	fi
}
