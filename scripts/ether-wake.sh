#!/bin/sh
# Usage: ether-wake.sh [node]...

[ "$(whoami)" = 'root' ] || \
	{ printf 'Root permission is needed!\n'; exit 1; }

ifname="$(ip -br -4 addr show | sed -E -n 's/^[[:blank:]]*([[:alnum:]]+)[[:blank:]]+.+10\.0\.0\.1.+$/\1/p')"

if [ "$#" -gt 0 ]; then
	for node in "$@"; do
		n="${node##*0}" # remove trailing zeros
		{ [ -n "${n}" ] && [ "${n}" -gt 0 ] && [ "${n}" -lt 255 ]; } || \
			{ printf 'Invalid node number: %s\n' "${node}"; continue; }

		mac="$(wwctl node list --net | sed -E -n 's/^.*[[:blank:]]+(.?.?(:.?.?){5})[[:blank:]]+10\.0\.2\.'"${n}"'.*$/\1/p')"
		[ -n "${mac}" ] && ether-wake -i "${ifname}" "${mac}"
	done
else
	macs="$(wwctl node list --net | sed -E -n 's/^.*[[:blank:]]+(.?.?(:.?.?){5}).*$/\1/p')"
	[ -n "${macs}" ] && for mac in ${macs}; do ether-wake -i "${ifname}" "${mac}"; done
fi
