#!/bin/zsh
# points.sh <run name> [config_key=value ...]: judges one build on every point the player reached (saves/player,
# refreshed by harvest.sh first) and on every chapter sweep (scenarios/*-chapters.txt), then sums up their verdicts in
# runs/<run name>/verdict.txt. A point loads its save through the game's own menus (scenarios/continue-<ID>.txt),
# then plays about 5 min. Runs on the player's installation, which has every game; same variables as run.sh.
#   ONLY=<ID>  that game only    QUICK=1  no chapter sweeps    TARGET  default 60    HOLD=1  keep the lock
A=~/Library/Android/sdk/platform-tools/adb
D=${0:A:h}
NAME=$1; shift
OWNER=${LOCK_OWNER:-vita3k} SERIES=$HOLD
export PREF=${PREF:-/storage/FBDD-1F17/Emulations/vita3k} TARGET=${TARGET:-60} HOLD=1
$D/lock.sh take $OWNER || exit 1
trap '[ "$SERIES" = 1 ] || $D/lock.sh release $OWNER' EXIT
# Picks up the points the player reached since the last series
$D/harvest.sh
mkdir -p $D/runs/$NAME; V=$D/runs/$NAME/verdict.txt; : > $V
judge() {
  local S=$D/runs/$NAME/$2/summary.txt
  echo "$1: $(grep -h -e '^verdict' -e '^ABORT' $S 2>/dev/null | tail -1 || echo 'no summary')" | tee -a $V
}
for P in $D/saves/player/${ONLY:-*}/*(N/); do
  ID=${P:h:t} R=${P:h:t}-${P:t}
  if [ ! -f $D/scenarios/continue-$ID.txt ]; then
    echo "$R: no route, write scenarios/continue-$ID.txt" | tee -a $V; continue
  fi
  SCENARIO=continue-$ID TITLE=$ID SAVE=player/$ID/${P:t} $D/run.sh $NAME/$R "$@" >/dev/null
  judge $R $R
done
[ "$QUICK" = 1 ] || for SC in $D/scenarios/*-chapters.txt(N); do
  [ -z "$ONLY" ] || grep -q "^title $ONLY" $SC || continue
  SCENARIO=${SC:t:r} $D/run.sh $NAME/${SC:t:r} "$@" >/dev/null
  judge ${SC:t:r} ${SC:t:r}
done
