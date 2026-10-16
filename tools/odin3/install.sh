#!/bin/zsh
# install.sh <apk>: installs a Vita3K build on the Odin 3 and points it at the shared game install
# (/storage/emulated/0/vita3k-bench/vita). With a build of this branch, also fills that install the first time:
# firmware (PSVUPDAT.PUP), font package (PSP2UPDAT.PUP), then the pkgs, rif licenses and patches, and the NoNpDrm
# dumps (<ID>.zip or <ID>.vpk with app/, patch/ and the work.bin license), all copied into
# /sdcard/Download/vita3k-bench/ with adb (the app cannot read files another app owns, nor the SD card).
# The caller holds the lock (tools/odin3/lock.sh take).
A=~/Library/Android/sdk/platform-tools/adb
APK=$1
V=/storage/emulated/0/vita3k-bench/vita
B=/sdcard/Download/vita3k-bench
[ -f "$APK" ] || { echo "usage: install.sh <apk>" >&2; exit 2; }
PKG=$(${$(ls -d ~/Library/Android/sdk/build-tools/*/ | tail -1)}aapt2 dump packagename $APK) || exit 1
F=/storage/emulated/0/Android/data/$PKG/files
$A install -r $APK | tail -1 || exit 1
$A shell appops set $PKG MANAGE_EXTERNAL_STORAGE allow
$A shell mkdir -p $V

has() { [ "$($A shell "[ -e $1 ] && echo y")" = y ]; }
installing() { $A shell dumpsys activity services $PKG | grep -q InstallForegroundService; }
# A running MainActivity would only be brought to front (same root intent, extras ignored): start it afresh
bench() {
  $A shell am force-stop $PKG
  $A shell am start -n $PKG/org.vita3k.emulator.MainActivity "$@" >/dev/null
  for i in $(seq 10); do installing && break; sleep 1; done
  for i in $(seq 900); do installing || return 0; sleep 2; done
  echo "install still running after 30 min" >&2; return 1
}

if ! has $F/config.yml; then
  $A shell am start -n $PKG/org.vita3k.emulator.MainActivity >/dev/null
  for i in $(seq 30); do has $F/config.yml && break; sleep 1; done
fi
$A shell am force-stop $PKG
TMP=$(mktemp -d)
$A pull $F/config.yml $TMP/config.yml >/dev/null || exit 1
python3 -I ${0:A:h}/setcfg.py $TMP/config.yml $TMP/config.yml pref-path=$V/ || exit 1
$A push $TMP/config.yml $F/config.yml >/dev/null
rm -rf $TMP

# An empty partition is created at the first boot: only its content tells that a PUP was installed
for pup part in PSVUPDAT.PUP vs0 PSP2UPDAT.PUP sa0; do
  [ -n "$($A shell ls $V/$part 2>/dev/null)" ] && continue
  echo "installing $pup"
  bench --es bench_install_pup $B/$pup
  [ -n "$($A shell ls $V/$part 2>/dev/null)" ] || { echo "$pup install failed" >&2; exit 1; }
done
# Games before their patches: Vita3K merges a patch into ux0/app/<ID>, changing its param.sfo, so installed
# patches are listed in $V/.patches
PKGS=$($A shell ls $B | tr -d '\r' | grep '\.pkg$')
sfo() { $A shell md5sum $V/ux0/app/$1/sce_sys/param.sfo 2>/dev/null; }
for pkg in $(echo $PKGS | grep -v -- '-patch\.pkg$') $(echo $PKGS | grep -- '-patch\.pkg$'); do
  ID=${pkg%%[-.]*}
  if [[ $pkg == *-patch.pkg ]]; then
    $A shell cat $V/.patches 2>/dev/null | tr -d '\r' | grep -qx $pkg && continue
    BEFORE=$(sfo $ID)
  else
    has $V/ux0/app/$ID && continue
  fi
  echo "installing $pkg"
  if has $B/$ID.rif; then
    bench --es bench_install_pkg $B/$pkg --es bench_install_license $B/$ID.rif
  else
    bench --es bench_install_pkg $B/$pkg
  fi
  if [[ $pkg == *-patch.pkg ]]; then
    [ -n "$BEFORE" ] && [ "$(sfo $ID)" != "$BEFORE" ] || { echo "$pkg install failed" >&2; exit 1; }
    $A shell "echo $pkg >> $V/.patches"
  else
    has $V/ux0/app/$ID || { echo "$pkg install failed" >&2; exit 1; }
  fi
done
for arc in $($A shell ls $B | tr -d '\r' | grep -E '\.(zip|vpk)$'); do
  ID=${arc%%[-.]*}
  has $V/ux0/app/$ID && continue
  echo "installing $arc"
  bench --es bench_install_archive $B/$arc
  has $V/ux0/app/$ID || { echo "$arc install failed" >&2; exit 1; }
done
$A shell am force-stop $PKG
$A shell ls $V/ux0/app | tr -d '\r' | paste -sd' ' -
