wireguard() {
	if [[ "$1" == 'import' && -n "$2" ]]; then
		nmcli connection import type wireguard file "$2"
	fi
}
