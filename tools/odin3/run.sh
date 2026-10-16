#!/bin/zsh
# run.sh <run name> [config_key=value ...]: boots a game in a Vita3K build on the Odin 3, plays the scenario
# and writes the measured segments to runs/<run name>/.
#   PKG       Vita3K package (default: this branch's debuggable build)
#   SCENARIO  scenarios/<SCENARIO>.txt (default uncharted-intro); its `title` and `save` lines pick the game
#             and the save restored before booting, a `patch` line a game patch from patches/ (Vita3K format)
#   TARGET    frame rate the game aims for, for the slow-frame count (default 30)
#   KEEP=1    leave the game running at the end
#   COLD=1    start from an empty shader and pipeline cache (first play)
#   HOLD=1    keep the lock for the next run of a series (the series releases it, within ~15 min)
#   LOCK_OWNER  lock owner (default vita3k): each parallel session has its own
#   PROFILE=<segment>:<s>  simpleperf samples the process for <s> seconds from the start of that segment
#             (its numbers are skewed by the sampling: profile in a run of its own) into runs/<name>/profile.txt
# Scenario lines: title <ID> | save <name> | patch <name> | wait <s> | btn <name> [ms] | stick|rstick <x> <y> <ms> |
#   tap <x> <y> | repeat <n> <line> | shot <name> | measure <label> ... end
#   (inputs between measure and end run while measuring)
A=~/Library/Android/sdk/platform-tools/adb
D=${0:A:h}
NAME=$1; shift
OUT=$D/runs/$NAME
PKG=${PKG:-org.vita3k.emulator.odin3.debug}
SC=$D/scenarios/${SCENARIO:-uncharted-intro}.txt
F=/storage/emulated/0/Android/data/$PKG/files
# Every build shares one installed copy of the games (pref-path), so builds are compared on the same data;
# PREF=<dir> runs on another installation, such as the player's on the SD card
V=${PREF:-/storage/emulated/0/vita3k-bench/vita}
T=/data/local/tmp/vita3k
[ -f $SC ] || { echo "no scenario $SC"; exit 2; }
TITLE=${TITLE:-$(sed -n 's/^title \([^ #]*\).*/\1/p' $SC)}
SAVE=$(sed -n 's/^save \([^ #]*\).*/\1/p' $SC)
PATCH=$(sed -n 's/^patch \([^ #]*\).*/\1/p' $SC)
rm -rf $OUT; mkdir -p $OUT $D/base/$PKG || exit 1

OWNER=${LOCK_OWNER:-vita3k}
$D/lock.sh take $OWNER || exit 1
# The build's own config, its per-game config and the player's save in the shared installation come back at
# the end, so a player's build (PKG=...) keeps its progress and settings
trap '$A shell pkill -f $T/poll.sh; [ "$KEEP" = 1 ] || { $A shell am force-stop $PKG
  [ -f $D/base/$PKG/config.yml ] && $A push $D/base/$PKG/config.yml $F/config.yml >/dev/null
  for p in $PUT_ASIDE; do $A shell "[ -e $p.player ] && rm -rf $p && mv $p.player $p"; done
  [ "$NEWPATCH" = 1 ] && $A shell rm -f $F/patch/$PATCH.txt; }
  [ "$HOLD" = 1 ] || $D/lock.sh release $OWNER' EXIT
PUT_ASIDE=()
put_aside() { PUT_ASIDE+=($1); $A shell "[ -e $1.player ] || { [ -e $1 ] && mv $1 $1.player; }; rm -rf $1"; }

focused() { $A shell dumpsys window | grep mCurrentFocus | grep -q "$PKG/org.vita3k.emulator.Emulator"; }
pad() { focused || { echo "ABORT: Vita3K lost the focus" | tee -a $OUT/summary.txt; exit 1; }; $A shell sh $T/pad.sh "$@"; }
# A shot with a reference in refs/<scenario>/ (a correct native-resolution render) also judges the picture
shot() {
  # The device clock, to match a shot with the lines of vita3k.log
  print "$1 $($A shell date +%T.%N | cut -c1-12)" >> $OUT/shots.txt
  $A exec-out screencap -p > $OUT/$1.png && sips -Z 960 $OUT/$1.png --out $OUT/$1.png >/dev/null || return
  local ref=$D/refs/${SC:t:r}/$1.png
  [ -f $ref ] && python3 -I $D/imgdiff.py $ref $OUT/$1.png | tee -a $OUT/summary.txt
}

$A shell mkdir -p $T
$A push $D/pad.sh $D/poll.sh $T/ >/dev/null
$A shell am force-stop $PKG
# Start every run from a cool GPU so thermal throttling does not depend on the previous run
for i in $(seq 45); do [ $($A shell cat /sys/class/kgsl/kgsl-3d0/temp | tr -d '\r') -lt 42000 ] && break; sleep 2; done

[ -f $D/base/$PKG/config.yml ] || $A pull $F/config.yml $D/base/$PKG/config.yml >/dev/null || exit 1
$A shell appops set $PKG MANAGE_EXTERNAL_STORAGE allow
# Non-Release builds bundle the Vulkan validation layer and enable it by default: never measure with it
python3 -I $D/setcfg.py $D/base/$PKG/config.yml $OUT/config.yml pref-path=$V/ validation-layer=false "$@" || exit 1
$A push $OUT/config.yml $F/config.yml >/dev/null
# A per-game config would silently override the global keys under test
put_aside $F/config/config_$TITLE.xml
[ "$COLD" = 1 ] && $A shell rm -rf $F/cache/shaders/$TITLE
if [ -n "$SAVE" ]; then
  [ -d $D/saves/$SAVE ] || { echo "ABORT: no save $SAVE" | tee $OUT/summary.txt; exit 1; }
  S=$V/ux0/user/00/savedata/$TITLE
  put_aside $S && $A shell mkdir -p ${S:h} && $A push $D/saves/$SAVE $S >/dev/null || exit 1
fi
# Vita3K applies the patches/<name>.txt whose name holds the title ID; a patch the build already had stays
if [ -n "$PATCH" ]; then
  [ -f $D/patches/$PATCH.txt ] || { echo "ABORT: no patch $PATCH" | tee $OUT/summary.txt; exit 1; }
  $A shell ls $F/patch/$PATCH.txt >/dev/null 2>&1 || NEWPATCH=1
  $A shell mkdir -p $F/patch && $A push $D/patches/$PATCH.txt $F/patch/ >/dev/null || exit 1
fi
$A shell input keyevent KEYCODE_WAKEUP; $A shell wm dismiss-keyguard
$A logcat -c
$A shell am start -n $PKG/org.vita3k.emulator.Emulator --es title_id $TITLE >/dev/null
for i in $(seq 60); do focused && break; sleep 1; done
focused || { echo "ABORT: the Emulator activity never got the focus" | tee $OUT/summary.txt; exit 1; }
echo "pkg=$PKG title=$TITLE scenario=${SC:t} edits=$* start=$(date +%T)" > $OUT/context.txt

# The Emulator activity has two BLAST SurfaceViews and only one of them gets the game's frames
game_layer() {
  local n
  for n in ${(u)${(f)"$($A shell dumpsys SurfaceFlinger --list | tr -d '\r' |
      grep -oE "SurfaceView\[$PKG/org\.vita3k\.emulator\.Emulator\]\(BLAST\)#[0-9]+")"}}; do
    print -r -- "$($A shell "dumpsys SurfaceFlinger --latency '$n'" | awk 'NF==3 && $2>0 {c++} END {print c+0}') $n"
  done | sort -rn | head -1 | cut -d' ' -f2-
}
LAYER=""
SEG=""
seg_begin() {
  SEG=$OUT/$1; mkdir -p $SEG
  [ -n "$LAYER" ] || LAYER=$(game_layer)
  PID=$($A shell pidof $PKG | tr -d '\r')
  $A shell "cat /proc/$PID/task/*/stat" > $SEG/threads_start.txt
  $A shell sh $T/poll.sh 3600 > $SEG/poll.csv &
  [ "${PROFILE%:*}" = "$1" ] &&
    $A shell "simpleperf record --app $PKG --duration ${PROFILE#*:} -o $T/perf.data" > $OUT/simpleperf.log 2>&1 &
  # SurfaceFlinger keeps the last 128 presents (4 s at 30 fps): sample every second
  { while [ ! -f $SEG/.stop ]; do $A shell "dumpsys SurfaceFlinger --latency '$LAYER'"; sleep 1; done } > $SEG/sf_latency.txt &
  T0=$SECONDS
}
seg_end() {
  $A shell "cat /proc/$PID/task/*/stat" > $SEG/threads_end.txt
  echo $((SECONDS - T0)) > $SEG/duration
  touch $SEG/.stop; $A shell pkill -f $T/poll.sh; wait
  python3 -I $D/summarize.py $SEG ${TARGET:-30} | tee -a $OUT/summary.txt
  SEG=""
}
step() {
  case $1 in
    title|save|patch|""|\#*) ;;
    wait) sleep $2;;
    btn|stick|rstick) pad "$@";;
    # A short tap is not seen by the games: hold the finger 250 ms (screen pixels, 1920x1080 landscape)
    tap) focused || { echo "ABORT: Vita3K lost the focus" | tee -a $OUT/summary.txt; exit 1; }
      $A shell input swipe $2 $3 $2 $3 250;;
    repeat) local n=$2; shift 2; for i in $(seq $n); do step "$@"; done;;
    shot) [ -z "$SEG" ] || { echo "a screenshot during a measure stalls SurfaceFlinger" >&2; exit 2; }; shot $2;;
    measure) seg_begin $2;;
    end) seg_end;;
    *) echo "unknown scenario line: $*" >&2; exit 2;;
  esac
}
# Read the whole file first: adb shell would swallow the rest of the scenario from stdin
for line in "${(@f)$(<$SC)}"; do step ${=line%%\#*}; done
[ -z "$SEG" ] || seg_end

[ -z "$PROFILE" ] || $A shell "simpleperf report -i $T/perf.data --sort comm,symbol --percent-limit 0.3" \
  2>/dev/null | tr -d '\r' | head -n 120 > $OUT/profile.txt
# A guest thread stuck on a fault logs gigabytes: keep only both ends of a huge log
SZ=$($A shell stat -c %s $F/vita3k.log 2>/dev/null | tr -d '\r')
if [ "${SZ:-0}" -gt 33554432 ]; then
  { $A exec-out head -c 8388608 $F/vita3k.log; print "\n[run.sh: $SZ bytes, middle cut]"
    $A exec-out tail -c 8388608 $F/vita3k.log; } > $OUT/vita3k.log
  $A shell rm -f $F/vita3k.log
else
  $A pull $F/vita3k.log $OUT/vita3k.log >/dev/null 2>&1
fi
E=$(grep -c '|E|' $OUT/vita3k.log 2>/dev/null); W=$(grep -c '|W|' $OUT/vita3k.log 2>/dev/null)
echo "log: ${E:-0} errors, ${W:-0} warnings; top: $(grep '|E|' $OUT/vita3k.log 2>/dev/null |
  sed 's/^\[[^]]*\] |E| //' | cut -c1-60 | sort | uniq -c | sort -rn | head -3 | awk '{$1=$1};1' | paste -sd';' -)" |
  tee -a $OUT/summary.txt
focused || echo "WARNING: Vita3K no longer has the focus (crash?)" | tee -a $OUT/summary.txt
