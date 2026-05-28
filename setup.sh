#!/usr/bin/env bash
#
# Interactive bootstrap for the dotfiles repository.
#
# Run on a fresh Ubuntu LTS install. Resolves the minimum tooling required by
# the rest of the install pipeline (jq, yq-go, shellcheck, shfmt), then prints
# the next-step prompts. Idempotent — safe to re-run.

set -euo pipefail

DOTFILES_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export DOTFILES_ROOT

# shellcheck source=scripts/lib/log.sh
source "${DOTFILES_ROOT}/scripts/lib/log.sh"
# shellcheck source=scripts/lib/os.sh
source "${DOTFILES_ROOT}/scripts/lib/os.sh"
# shellcheck source=scripts/lib/pkg.sh
source "${DOTFILES_ROOT}/scripts/lib/pkg.sh"

# ------------------------------------------------------------------------------
# Prompts
# ------------------------------------------------------------------------------

confirm() {
	local prompt=$1 default=${2:-y} reply
	local hint="[Y/n]"
	[[ ${default} == n ]] && hint="[y/N]"

	read -r -p "${prompt} ${hint} " reply
	reply=${reply,,}
	[[ -z ${reply} ]] && reply=${default}
	[[ ${reply} == y || ${reply} == yes ]]
}

# ------------------------------------------------------------------------------
# Steps
# ------------------------------------------------------------------------------

check_environment() {
	log_step "checking environment"
	require_not_root
	require_ubuntu_min 24
	log_info "host: $(os_id) $(os_version_id) ($(os_codename))"
	if ! is_ubuntu_lts; then
		log_warn "this is not an LTS release — supported but not the primary target"
	fi
}

install_bootstrap_deps() {
	log_step "installing bootstrap dependencies"

	# Core CLI tooling needed by the rest of the install pipeline. Kept tight
	# on purpose — anything heavier belongs in data/packages.yaml. `gum` is in
	# here because the shell-side overrides (e.g. `git profile`) depend on it.
	pkg_apt_update
	pkg_apt_install \
		ca-certificates \
		curl \
		git \
		gum \
		jq \
		wget

	# yq-go ships as a snap on Ubuntu. The apt 'yq' package is the unrelated
	# python yq wrapper, which we do not want.
	if ! command -v yq >/dev/null 2>&1; then
		pkg_snap_install yq
	else
		log_debug "yq already on PATH"
	fi

	# Developer tooling (used by 'make lint' and 'make fmt'). Optional — skip
	# if the user prefers a leaner host.
	if confirm "install dev tooling (shellcheck, shfmt) for make lint/fmt?" y; then
		pkg_apt_install shellcheck shfmt
	fi
}

next_steps() {
	log_step "bootstrap complete"
	cat <<-EOF

		Next steps:

		  make help          - list available targets
		  make link          - link configured dotfile categories
		  make status        - show current symlink state

		Repo root: ${DOTFILES_ROOT}
	EOF
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
	check_environment
	install_bootstrap_deps
	next_steps
}

main "$@"
