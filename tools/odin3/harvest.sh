#!/bin/zsh
# harvest.sh: copies the save of every game the player has played on the Odin 3 (SD card installation) into
# saves/player/<ID>/<date of the save>, once per distinct save, so that points.sh replays every point the player
# reached on each build. Only reads the console: launches nothing and leaves the player's saves untouched.
#   PREF  the player's installation (default the SD card's)
A=~/Library/Android/sdk/platform-tools/adb
D=${0:A:h}
V=${PREF:-/storage/FBDD-1F17/Emulations/vita3k}
X=$V/ux0/user/00/savedata
TMP=$(mktemp -d); trap 'rm -rf $TMP' EXIT
digest() { (cd $1 && find . -type f | LC_ALL=C sort | xargs cat | md5 -q); }
for ID in ${(f)"$($A shell ls $X | tr -d '\r' | grep -E '^[A-Z]{4}[0-9]{5}$')"}; do
  # Named after its newest file: when the player last saved
  STAMP=$($A shell "find $X/$ID -type f -exec stat -c %Y {} +" | tr -d '\r' | sort -n | tail -1)
  [ -n "$STAMP" ] || continue
  NEW=$TMP/$ID; $A pull $X/$ID $NEW >/dev/null || { echo "$ID: pull failed"; continue; }
  SUM=$(digest $NEW) DUP=""
  for old in $D/saves/player/$ID/*(N/); do [ "$(digest $old)" = "$SUM" ] && DUP=${old:t} && break; done
  if [ -n "$DUP" ]; then echo "$ID: known ($DUP)"; continue; fi
  DST=$D/saves/player/$ID/$(date -r $STAMP +%Y%m%d-%H%M)
  mkdir -p ${DST:h} && mv $NEW $DST && echo "$ID: new point ${DST:t}"
done
