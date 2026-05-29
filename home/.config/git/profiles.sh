# Profile metadata for the `git profile` subcommand. Sourced by
# scripts/overrides/git.sh on shell startup.
#
# The Sam profile is the public default and lives inline here. The artifex
# profile's name / email / signingkey are sops-encrypted (see secrets.yaml)
# and rendered into ~/.config/git/profiles.d/artifex.env by
# scripts/setup/secrets.sh — sourced below when present. On a machine
# without the age key, artifex stays unconfigured and VALID_PROFILES is
# Sam-only.

declare -A PROFILE_NAME=(
	[sam]='Sam Ariafar'
)
declare -A PROFILE_EMAIL=(
	[sam]='me@samariafar.com'
)
declare -A PROFILE_SIGNINGKEY=(
	[sam]='43980348B058F190C95BD47F8412223052412037'
)
declare -A PROFILE_SSHKEY=(
	[sam]='~/Vault/Keys/Sam/ssh-private.key'
	[artifex]='~/Vault/Keys/Artifex/ssh-private.key'
)
declare -A PROFILE_EMOJI=(
	[sam]='😃'
	[artifex]='😎'
)
VALID_PROFILES=(sam)

# Layer in the artifex profile if the sops-rendered env file is present.
# Missing on fresh clones / machines without the user's age key — silent
# no-op in that case.
if [[ -f "${HOME}/.config/git/profiles.d/artifex.env" ]]; then
	# shellcheck disable=SC1091
	source "${HOME}/.config/git/profiles.d/artifex.env"
	if [[ -n "${PROFILE_ARTIFEX_NAME:-}" ]]; then
		PROFILE_NAME[artifex]=$PROFILE_ARTIFEX_NAME
		PROFILE_EMAIL[artifex]=$PROFILE_ARTIFEX_EMAIL
		PROFILE_SIGNINGKEY[artifex]=$PROFILE_ARTIFEX_SIGNINGKEY
		VALID_PROFILES+=(artifex)
	fi
fi
