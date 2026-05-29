upgrade() {
	sudo apt-get update
	sudo apt-get upgrade -y
	if command -v snap >/dev/null 2>&1; then
		sudo snap refresh
	fi
	if command -v flatpak >/dev/null 2>&1; then
		flatpak update -y
	fi
}
