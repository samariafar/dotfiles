fonts() {
	case "$1" in
		reload)
			fc-cache -fv
			;;
		reset)
			fc-cache -fvr
			;;
		*)
			echo 'Usage: fonts {reload|reset}'
			echo '  reload  rescan and update the font cache (fast, incremental)'
			echo '  reset   wipe and rebuild the font cache from scratch'
			return 1
			;;
	esac
}
