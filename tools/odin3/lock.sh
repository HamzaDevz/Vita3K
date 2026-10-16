#!/bin/zsh
# lock.sh take|release|show <owner>: the Odin 3 is shared with other sessions (Eden). Nobody launches a game
# or measures without holding /data/local/tmp/odin3.lock; take also refuses while an Eden game has the focus.
# A refused take queues its owner in odin3.next: nobody else takes the lock while that reservation is under 20 min old.
A=~/Library/Android/sdk/platform-tools/adb
L=/data/local/tmp/odin3.lock
N=/data/local/tmp/odin3.next
OWNER=${2:-vita3k}
# Our own reservation is refreshed on every refused try; another owner's is never replaced while fresh
busy() { [ -n "$QUEUED" ] || $A shell "echo \"$OWNER \$(date +%s)\" > $N"; echo "busy: $1"; exit 1; }
case $1 in
  take)
    [ "$($A shell cat $L 2>/dev/null | tr -d '\r' | cut -d' ' -f1)" = "$OWNER" ] && exit 0
    NEXT=$($A shell cat $N 2>/dev/null | tr -d '\r')
    QUEUED=""
    if [ -n "$NEXT" ] && [ "${NEXT% *}" != "$OWNER" ] && [ $(( $(date +%s) - ${NEXT##* } )) -lt 1200 ]; then
      QUEUED=1; busy "queued for ${NEXT% *}"
    fi
    $A shell dumpsys window | grep mCurrentFocus | grep -q yuzu_emu && busy "an Eden game has the focus"
    # The Eden Zelda series (eden/tools/odin3/run_variant.sh) measures without taking the lock
    pgrep -f 'run_variant\.sh|eden/tools/odin3/(measure\.sh|play\.py)' >/dev/null &&
      busy "an Eden bench script is running on this Mac"
    if $A shell "set -C; echo \"$OWNER \$(date +%s)\" > $L" 2>/dev/null; then
      $A shell "grep -q '^$OWNER ' $N 2>/dev/null && rm $N"; exit 0
    fi
    busy "$($A shell cat $L | tr -d '\r')";;
  release) $A shell "grep -q '^$OWNER ' $L 2>/dev/null && rm $L"; exit 0;;
  show) $A shell cat $L 2>/dev/null | tr -d '\r';;
  *) echo "usage: lock.sh take|release|show [owner]" >&2; exit 2;;
esac
