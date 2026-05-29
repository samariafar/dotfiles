#!/usr/bin/env bash
#
# Category: ssh
#
# Symlinks ~/.ssh/config from the repo, ensures the ~/.ssh dir has the right
# perms, and seeds ~/.ssh/known_hosts with literal alias entries for github.com
# (as gh.anon/gh.orig/github.com) and gitlab.com (as gl.orig/gitlab.com).
# Mirrors nixcfg's home.activation.seedKnownHosts step — GitKraken/libssh2
# reads known_hosts directly and ignores HostKeyAlias, so the aliases have to
# resolve there literally.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
export DOTFILES_ROOT

# shellcheck source=../lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=../lib/link.sh
source "${DOTFILES_ROOT}/scripts/lib/link.sh"
# shellcheck source=../lib/pkg.sh
source "${DOTFILES_ROOT}/scripts/lib/pkg.sh"

CATEGORY=ssh

LINKS=(
	"home/.ssh/config:${HOME}/.ssh/config"
)

KNOWN_HOSTS="${HOME}/.ssh/known_hosts"

ensure_ssh_dir() {
	mkdir -p "${HOME}/.ssh"
	chmod 700 "${HOME}/.ssh"
	touch "${KNOWN_HOSTS}"
	chmod 600 "${KNOWN_HOSTS}"
}

# seed_known_hosts UPSTREAM_HOST ALIASES MARKER
#   Adds an entry for the given upstream's host key to known_hosts, but rewrites
#   the line so it's listed under ALIASES (a comma-separated list, e.g.
#   "gh.anon,gh.orig,github.com"). The MARKER is the first alias and is
#   grep-checked to keep the operation idempotent.
seed_known_hosts() {
	local upstream=$1 aliases=$2 marker=$3
	if grep -q "^${marker}[, ]" "${KNOWN_HOSTS}"; then
		log_debug "known_hosts: ${marker} already seeded"
		return 0
	fi
	if ! command -v ssh-keyscan >/dev/null 2>&1; then
		log_warn "ssh-keyscan not available — skipping known_hosts seed for ${upstream}"
		return 0
	fi
	local scan
	if ! scan=$(ssh-keyscan "${upstream}" 2>/dev/null); then
		log_warn "ssh-keyscan failed for ${upstream} — skipping (network down?)"
		return 0
	fi
	# Each ssh-keyscan line starts with the queried hostname; replace it with
	# the alias list so every alias resolves to the same host key.
	printf '%s\n' "${scan}" | sed "s|^${upstream}|${aliases}|" >> "${KNOWN_HOSTS}"
	log_success "seeded ${aliases} → ${upstream} host keys"
}

cmd_install() {
	log_step "${CATEGORY}: install packages"
	pkg_apt_install openssh-client
	ensure_ssh_dir
	log_step "${CATEGORY}: seed known_hosts"
	seed_known_hosts github.com "gh.anon,gh.orig,github.com" gh.anon
	seed_known_hosts gitlab.com "gl.orig,gitlab.com" gl.orig
}

cmd_link() {
	ensure_ssh_dir
	log_step "${CATEGORY}: link"
	local entry src dest
	for entry in "${LINKS[@]}"; do
		src=${entry%%:*}
		dest=${entry#*:}
		link_file "${DOTFILES_ROOT}/${src}" "${dest}"
	done
	chmod 600 "${HOME}/.ssh/config" 2>/dev/null || true
}

cmd_unlink() {
	log_step "${CATEGORY}: unlink"
	local entry dest
	for entry in "${LINKS[@]}"; do
		dest=${entry#*:}
		unlink_file "${dest}"
	done
}

cmd_status() {
	log_step "${CATEGORY}: status"
	local entry dest
	for entry in "${LINKS[@]}"; do
		dest=${entry#*:}
		link_status "${dest}"
	done
	if grep -q '^gh.anon[, ]' "${KNOWN_HOSTS}" 2>/dev/null; then
		printf 'seeded      known_hosts: gh.anon\n'
	else
		printf 'missing     known_hosts: gh.anon\n'
	fi
	if grep -q '^gl.orig[, ]' "${KNOWN_HOSTS}" 2>/dev/null; then
		printf 'seeded      known_hosts: gl.orig\n'
	else
		printf 'missing     known_hosts: gl.orig\n'
	fi
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
