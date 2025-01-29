#!/bin/sh
# Usage: ww-ether-wake.sh [node]...

[ "$(whoami)" = 'root' ] || \
	{ printf 'Root permission is needed!\n'; exit 1; }

if_name="$(ip -br -4 addr show | sed -E -n 's/^[[:blank:]]*([[:alnum:]]+)[[:blank:]]+.+10\.0\.0\.1.+$/\1/p')"

if [ "$#" -gt 0 ]; then
	for _node in "$@"; do
		node="$(printf '%s' "${_node}" | sed -E 's/(\.)/\\\1/g')" # escape special dot character
		mac_addr="$(wwctl node list --net | sed -E -n 's/^[[:blank:]]*'"${node}"'[[:blank:]]+.+[[:blank:]]+(.?.?(:.?.?){5}).*$/\1/p')"

		[ -n "${mac_addr}" ] || { printf 'Unavailable node: %s\n' "${_node}"; continue; }

		ether-wake -i "${if_name}" "${mac_addr}"
	done
else
	mac_addrs="$(wwctl node list --net | sed -E -n 's/^.*[[:blank:]]+(.?.?(:.?.?){5}).*$/\1/p')"
	[ -n "${mac_addrs}" ] && for mac_addr in ${mac_addrs}; do ether-wake -i "${if_name}" "${mac_addr}"; done
fi
