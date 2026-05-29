cleanup() {
	sudo apt-get autoremove -y
	sudo apt-get clean
	if command -v docker >/dev/null 2>&1; then
		docker system prune --all --volumes --force
	fi
	if command -v flatpak >/dev/null 2>&1; then
		sudo flatpak uninstall --unused -y
	fi
	if command -v snap >/dev/null 2>&1; then
		# Old snap revisions held in case of rollback. List + prune by hand to
		# avoid removing in-use revisions.
		LANG=C snap list --all | awk '/disabled/{print $1, $3}' | while read -r name rev; do
			sudo snap remove "$name" --revision="$rev"
		done
	fi
}
