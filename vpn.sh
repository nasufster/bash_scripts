#!/bin/bash

VPNSTART="pppd call soton nodetach require-mppe"

if [ $UID -eq 0 ]; then
	eval "$VPNSTART"
elif [ "$(which fakeroot 2> /dev/null)" ]; then
	echo "$VPNSTART" | fakeroot
else 
	su -c "$VPNSTART"
fi
