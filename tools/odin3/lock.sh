#!/bin/zsh
# lock.sh take|release|show <owner>: the Odin 3 is shared with other sessions (Eden, Dolphin, Cemu...). Nobody
# launches a game or measures without holding /data/local/tmp/odin3.lock; take also refuses while an Eden game has
# the focus. A refused take queues its owner in odin3.next, one line per owner as the other emulators' lock.sh do:
# nobody takes the lock while an owner queued before them has a reservation under 20 min old.
A=~/Library/Android/sdk/platform-tools/adb
L=/data/local/tmp/odin3.lock
N=/data/local/tmp/odin3.next
OWNER=${2:-vita3k}
queue() { $A shell "grep -q '^$OWNER ' $N 2>/dev/null || echo \"$OWNER \$(date +%s)\" >> $N"; echo "busy: $1"; exit 1; }
case $1 in
  take)
    [ "$($A shell cat $L 2>/dev/null | tr -d '\r' | cut -d' ' -f1)" = "$OWNER" ] && exit 0
    $A shell cat $L >/dev/null 2>&1 && queue "$($A shell cat $L | tr -d '\r')"
    # Fresh reservations of other owners queued before ours go first
    NOW=$(date +%s)
    for e in ${(f)"$($A shell cat $N 2>/dev/null | tr -d '\r')"}; do
      [ "${e% *}" = "$OWNER" ] && break
      [ $((NOW - ${e##* })) -lt 1200 ] && queue "queued after ${e% *}"
    done
    $A shell dumpsys window | grep mCurrentFocus | grep -q yuzu_emu && queue "an Eden game has the focus"
    # The Eden Zelda series (eden/tools/odin3/run_variant.sh) measures without taking the lock
    pgrep -f 'run_variant\.sh|eden/tools/odin3/(measure\.sh|play\.py)' >/dev/null &&
      queue "an Eden bench script is running on this Mac"
    if $A shell "set -C; echo \"$OWNER \$(date +%s)\" > $L" 2>/dev/null; then
      $A shell "sed -i '/^$OWNER /d' $N 2>/dev/null"; exit 0
    fi
    queue "$($A shell cat $L | tr -d '\r')";;
  release) $A shell "grep -q '^$OWNER ' $L 2>/dev/null && rm $L"; exit 0;;
  show) $A shell cat $L $N 2>/dev/null | tr -d '\r';;
  *) echo "usage: lock.sh take|release|show [owner]" >&2; exit 2;;
esac
