webdl() {
	local url="$1"

	wget --mirror --page-requisites --adjust-extension --convert-links --no-parent "$url"
}
