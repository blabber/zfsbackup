#!/bin/sh

# "THE BEER-WARE LICENSE" (Revision 42):
# <tobias.rehbein@web.de> wrote this file. As long as you retain this notice
# you can do whatever you want with this stuff. If we meet some day, and you
# think this stuff is worth it, you can buy me a beer in return.
#                                                             Tobias Rehbein

ZPOOL='/sbin/zpool'
ZFS='/sbin/zfs'
AWK='/usr/bin/awk'
GREP='/usr/bin/grep'

# Variables to set in ~/.zfsbackup:
# SRCPOOLS - a space seperated list of pools that should be backed up
# TGTDATASET - the dataset that should receive the backups
if ! [ -r "$HOME/.zfsbackup" ]
then
	echo "Can't read ~/.zfsbackup"
	exit 1
fi
. "$HOME/.zfsbackup"

if [ -z "$SRCPOOLS" ]
then
	echo '$SRCPOOLS is not set' >&2
	exit 1
fi

if [ -z "$TGTDATASET" ]
then
	echo '$TGTDATASET is not set' >&2
	exit 1
fi

echo 'Checking SRCPOOLS...' >&2
for SRCPOOL in $SRCPOOLS
do
	printf '  %s... ' "$SRCPOOL" >&2
	if "$ZPOOL" list -H | \
		"$AWK" '{ print $1 }' | \
		"$GREP" -q "^$SRCPOOL\$"
	then
		echo "ok" >&2
	else
		echo "not found" >&2
		exit 1
	fi
done

echo 'Checking TGTDATASET...' >&2
printf '  %s... ' "$TGTDATASET" >&2
if "$ZFS" list "$TGTDATASET" >/dev/null 2>&1
then
	echo "ok" >&2
else
	echo "not found" >&2
	exit 1
fi

# Everything seems fine so far, let's have a look at the parameters...
case "$#" in
1)	;;
2)	IFLAG="-i $1"
	;;
*)	echo "usage: zfsbackup.sh [snapshot] snapshot" >&2
	exit 1
	;;
esac
SNAP="$1"

# Let's go
echo "Backing up '$SNAP'"
for SRCPOOL in $SRCPOOLS
do
	for SRCDATASET in $("$ZFS" list -rH "$SRCPOOL" | "$AWK" '{ print $1 }')
	do
		echo "Sending '$SRCDATASET@$SNAP'" >&2
		"$ZFS" send $IFLAG "$SRCDATASET@$SNAP" | "$ZFS" receive "$TGTDATASET/$SRCDATASET@$SNAP"
	done
done
