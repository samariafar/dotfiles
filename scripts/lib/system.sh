# shellcheck shell=bash
#
# Helpers for the system-level install scripts under scripts/install/{sshd,
# dns, firewall, sysctl, sudo, network}.sh. Each of these scripts deploys
# files into /etc/ via sudo; the helpers below keep that path uniform.

# system_install SRC DEST [MODE]
#   Copy SRC to DEST under /etc with sudo + chmod. Skips when SRC is missing,
#   and is a no-op when DEST already matches SRC byte-for-byte. Default mode
#   is 0644.
system_install() {
	local src=$1 dest=$2 mode=${3:-0644}
	if [[ ! -r ${src} ]]; then
		log_warn "system_install: source missing: ${src}"
		return 0
	fi
	if sudo test -r "${dest}"; then
		if sudo cmp -s "${src}" "${dest}"; then
			log_debug "system_install: already up to date: ${dest}"
			return 0
		fi
		sudo cp -a "${dest}" "${dest}.dotfiles-bak.$(date +%Y%m%d-%H%M%S)"
	fi
	sudo install -Dm"${mode}" "${src}" "${dest}"
	log_success "system_install: ${dest}"
}

# system_install_validated SRC DEST MODE VALIDATOR
#   Like system_install but runs VALIDATOR (a shell command, with the
#   candidate file path appended as its final argument) before swapping into
#   place. Used for sudoers / nginx / sshd-style configs where a syntax error
#   bricks the host.
system_install_validated() {
	local src=$1 dest=$2 mode=$3 validator=$4
	if [[ ! -r ${src} ]]; then
		log_warn "system_install_validated: source missing: ${src}"
		return 0
	fi
	if ! ${validator} "${src}"; then
		die "system_install_validated: ${validator} rejected ${src} — refusing to install"
	fi
	system_install "${src}" "${dest}" "${mode}"
}

# system_require_ubuntu
#   Aborts cleanly unless we're on Ubuntu. System-layer scripts target Ubuntu
#   only; running them on any other distro is almost certainly a mistake.
system_require_ubuntu() {
	if ! is_ubuntu; then
		log_warn "system: not running on Ubuntu — skipping system-level install"
		return 1
	fi
	return 0
}
