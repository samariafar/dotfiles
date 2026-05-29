# shellcheck disable=SC2034
msg() {
	local information='\e[1;36m'
	local success='\e[1;32m'
	local warning='\e[1;33m'
	local error='\e[1;31m'
	local reset='\e[0m'
	echo -e "\n${!1}▣ ${2}:${reset}\n"
}

inf() { msg information "${1}"; }
scs() { msg success "${1}"; }
wrn() { msg warning "${1}"; }
err() { msg error "${1}"; }
