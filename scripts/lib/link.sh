# shellcheck shell=bash
#
# Idempotent symlink management with timestamped backups for displaced files.
# Source from any script:
#   source "${DOTFILES_ROOT}/scripts/lib/log.sh"
#   source "${DOTFILES_ROOT}/scripts/lib/link.sh"
#
# Conventions:
# - Source paths MUST be absolute (typically inside DOTFILES_ROOT).
# - Destination paths MAY be relative to $HOME; they're resolved before linking.
# - When DEST already exists and is not the desired symlink, it is moved into
#   $LINK_BACKUP_ROOT/<timestamp>/ preserving its path relative to $HOME.

LINK_BACKUP_ROOT=${LINK_BACKUP_ROOT:-${HOME}/.dotfiles-backup}

# Lazily create a single backup directory per run; reuses one timestamp so a
# batch of link operations all land in the same place.
_link_backup_dir() {
	if [[ -z ${_LINK_BACKUP_DIR:-} ]]; then
		_LINK_BACKUP_DIR=${LINK_BACKUP_ROOT}/$(date +%Y%m%d-%H%M%S)
		mkdir -p "${_LINK_BACKUP_DIR}"
		log_debug "backups for this run will land in ${_LINK_BACKUP_DIR}"
	fi
	printf '%s' "${_LINK_BACKUP_DIR}"
}

# Move a displaced file/dir into the backup tree, preserving its path under HOME.
_link_backup() {
	local dest=$1 backup_dir rel target
	backup_dir=$(_link_backup_dir)
	# Compute the destination's path relative to HOME when it lives under HOME;
	# otherwise fall back to the absolute path under the backup root.
	if [[ ${dest} == "${HOME}"* ]]; then
		rel=${dest#"${HOME}/"}
	else
		rel=${dest#/}
	fi
	target=${backup_dir}/${rel}
	mkdir -p "$(dirname "${target}")"
	mv "${dest}" "${target}"
	log_warn "backed up existing ${dest} → ${target}"
}

# link_file SRC DEST
#   Creates DEST as a symlink to SRC. Idempotent: returns silently when DEST is
#   already the desired symlink. Displaces existing DEST into the backup tree.
link_file() {
	local src=$1 dest=$2

	[[ -e ${src} ]] || die "link_file: source does not exist: ${src}"

	mkdir -p "$(dirname "${dest}")"

	if [[ -L ${dest} ]]; then
		local current
		current=$(readlink "${dest}")
		if [[ ${current} == "${src}" ]]; then
			log_debug "already linked: ${dest} → ${src}"
			return 0
		fi
		_link_backup "${dest}"
	elif [[ -e ${dest} ]]; then
		_link_backup "${dest}"
	fi

	ln -s "${src}" "${dest}"
	log_success "linked ${dest} → ${src}"
}

# unlink_file DEST
#   Removes DEST when it is a symlink into our DOTFILES_ROOT. Leaves anything
#   else alone (the user can manually inspect backups under LINK_BACKUP_ROOT).
unlink_file() {
	local dest=$1 root=${DOTFILES_ROOT:-}

	if [[ ! -L ${dest} ]]; then
		log_debug "not a symlink, skipping: ${dest}"
		return 0
	fi

	local current
	current=$(readlink "${dest}")
	if [[ -n ${root} && ${current} != "${root}"* ]]; then
		log_warn "symlink does not point into DOTFILES_ROOT, refusing to remove: ${dest} → ${current}"
		return 0
	fi

	rm "${dest}"
	log_success "unlinked ${dest}"
}

# link_status DEST
#   Prints one line describing DEST's current relationship to the repo.
#   - linked     : symlink into DOTFILES_ROOT (managed by us)
#   - foreign-ln : symlink pointing elsewhere (e.g. home-manager, stow)
#   - foreign    : exists, not a symlink
#   - missing    : does not exist
link_status() {
	local dest=$1 current root=${DOTFILES_ROOT:-}
	if [[ -L ${dest} ]]; then
		current=$(readlink "${dest}")
		if [[ -n ${root} && ${current} == "${root}"* ]]; then
			printf 'linked      %s → %s\n' "${dest}" "${current}"
		else
			printf 'foreign-ln  %s → %s\n' "${dest}" "${current}"
		fi
	elif [[ -e ${dest} ]]; then
		printf 'foreign     %s (exists, not a symlink)\n' "${dest}"
	else
		printf 'missing     %s\n' "${dest}"
	fi
}
