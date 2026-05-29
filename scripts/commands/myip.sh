myip() {
	(
		set +m
		{
			ip=$(curl -4 -s --max-time 3 ifconfig.me 2>/dev/null || echo 'Not available')
			echo "IPv4: $ip"
		} &
		{
			ip=$(curl -6 -s --max-time 3 ifconfig.me 2>/dev/null || echo 'Not available')
			echo "IPv6: $ip"
		} &
		wait
	)
}
