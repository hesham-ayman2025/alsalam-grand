#!/sbin/busybox sh
# Al Salam Grand OS - file-level recovery updater for Philips TV348_DVB.
# MODE is patched by tools/make_ota.py: noop | install | rollback
# It only touches files under /system/priv-app/AlSalamGrandHome and renames
# /system/app/Philipslauncher/Philipslauncher.apk. It never writes a block device.
MODE="@MODE@"
APK_SHA256="@APK_SHA256@"
BB="${BB:-/sbin/busybox}"
OUTFD="${2:-2}"
ZIP="${3:-}"
SYS="${SYS_MNT:-/system}"
BLK="/dev/block/platform/mstar_mci.0/by-name/system"
TMP="${TMP_DIR:-/tmp/alsalam}"
HOME_DIR="$SYS/priv-app/AlSalamGrandHome"
PH_DIR="$SYS/app/Philipslauncher"
PH_APK="$PH_DIR/Philipslauncher.apk"
PH_BAK="$PH_DIR/Philipslauncher.apk.alsalam-bak"
MOUNTED_BY_US=0

ui_print() { echo "ui_print $1" 1>&$OUTFD; echo "ui_print" 1>&$OUTFD; }
fail() { ui_print "FAILED: $1"; ui_print "No further changes were made."; finish_mount; exit 1; }

finish_mount() {
  [ "${SKIP_MOUNT:-0}" = "1" ] && return 0
  $BB sync
  $BB mount -o remount,ro "$SYS" 2>/dev/null
  [ "$MOUNTED_BY_US" = "1" ] && $BB umount "$SYS" 2>/dev/null
  return 0
}

mount_system_rw() {
  [ "${SKIP_MOUNT:-0}" = "1" ] && return 0
  if $BB grep -q " $SYS " /proc/mounts; then
    $BB mount -o remount,rw "$SYS" || fail "cannot remount $SYS read-write"
  else
    $BB mount -t ext4 -o rw "$BLK" "$SYS" || fail "cannot mount $SYS"
    MOUNTED_BY_US=1
  fi
}

mount_system_any() {
  [ "${SKIP_MOUNT:-0}" = "1" ] && return 0
  if ! $BB grep -q " $SYS " /proc/mounts; then
    $BB mount -t ext4 -o ro "$BLK" "$SYS" 2>/dev/null && MOUNTED_BY_US=1
  fi
}

preflight_device() {
  [ -f "$SYS/build.prop" ] || fail "$SYS/build.prop missing"
  $BB grep -q "^ro.product.model=TV348_DVB" "$SYS/build.prop" || fail "wrong model (expected TV348_DVB)"
  $BB grep -q "^ro.build.fingerprint=PHILIPS_AR/aosp_philips_ar_dvb/" "$SYS/build.prop" || fail "unexpected firmware fingerprint"
  ui_print "Device check OK: TV348_DVB / PHILIPS_AR"
}

case "$MODE" in
noop)
  ui_print "== Al Salam NOOP TEST (writes nothing) =="
  ui_print "zip: $ZIP"
  mount_system_any
  [ -f "$SYS/build.prop" ] && ui_print "$($BB grep -E '^ro.product.model=|^ro.build.fingerprint=' "$SYS/build.prop" | $BB tr '\n' ' ')" || ui_print "build.prop not readable"
  for a in unzip cp mv rm mkdir chmod chown sync mount umount sha256sum grep tr df ls; do
    if $BB --list 2>/dev/null | $BB grep -qx "$a"; then ui_print "applet ok: $a"; else ui_print "applet MISSING: $a"; fi
  done
  [ -f "$PH_APK" ] && ui_print "Philips launcher apk: present" || ui_print "Philips launcher apk: NOT present"
  [ -f "$PH_BAK" ] && ui_print "Philips backup: present (already switched)"
  [ -d "$HOME_DIR" ] && ui_print "AlSalam home dir: present" || ui_print "AlSalam home dir: absent"
  ui_print "$($BB df "$SYS" 2>/dev/null | $BB tail -n 1)"
  ui_print "NOOP finished. Nothing was changed."
  [ "${SKIP_MOUNT:-0}" = "1" ] || { [ "$MOUNTED_BY_US" = "1" ] && $BB umount "$SYS" 2>/dev/null; }
  exit 0
  ;;
install)
  ui_print "== Al Salam Grand OS: install Home (file-level) =="
  mount_system_rw
  preflight_device
  [ -f "$PH_APK" ] || [ -f "$PH_BAK" ] || fail "Philips launcher apk not found"
  $BB rm -rf "$TMP"; $BB mkdir -p "$TMP" || fail "no tmp dir"
  $BB unzip -o -q "$ZIP" payload/AlSalamGrandHome.apk -d "$TMP" || fail "cannot extract payload (unzip)"
  GOT="$($BB sha256sum "$TMP/payload/AlSalamGrandHome.apk" | $BB cut -d' ' -f1)"
  [ "$GOT" = "$APK_SHA256" ] || fail "payload checksum mismatch"
  $BB mkdir -p "$HOME_DIR" || fail "cannot create $HOME_DIR"
  $BB cp "$TMP/payload/AlSalamGrandHome.apk" "$HOME_DIR/AlSalamGrandHome.apk.new" || fail "copy failed"
  $BB sync
  GOT2="$($BB sha256sum "$HOME_DIR/AlSalamGrandHome.apk.new" | $BB cut -d' ' -f1)"
  [ "$GOT2" = "$APK_SHA256" ] || { $BB rm -f "$HOME_DIR/AlSalamGrandHome.apk.new"; fail "written file checksum mismatch"; }
  $BB mv "$HOME_DIR/AlSalamGrandHome.apk.new" "$HOME_DIR/AlSalamGrandHome.apk" || fail "rename failed"
  $BB chmod 644 "$HOME_DIR/AlSalamGrandHome.apk"; $BB chmod 755 "$HOME_DIR"
  $BB chown 0:0 "$HOME_DIR/AlSalamGrandHome.apk" "$HOME_DIR"
  # Philips launcher is renamed (not deleted) so rollback is a plain rename.
  if [ -f "$PH_APK" ] && [ ! -f "$PH_BAK" ]; then
    $BB mv "$PH_APK" "$PH_BAK" || fail "cannot rename Philips launcher"
  fi
  $BB sync
  ui_print "Installed: $HOME_DIR/AlSalamGrandHome.apk"
  ui_print "Philips launcher renamed to .alsalam-bak (restorable)."
  finish_mount
  ui_print "DONE. Reboot the TV."
  exit 0
  ;;
rollback)
  ui_print "== Al Salam Grand OS: rollback to Philips launcher =="
  mount_system_rw
  preflight_device
  if [ -f "$PH_BAK" ]; then
    if [ -f "$PH_APK" ]; then $BB rm -f "$PH_BAK"; else $BB mv "$PH_BAK" "$PH_APK" || fail "cannot restore Philips launcher"; fi
  fi
  [ -f "$PH_APK" ] || fail "Philips launcher apk is still missing after rollback"
  $BB rm -rf "$HOME_DIR"
  $BB sync
  ui_print "Philips launcher restored; Al Salam Home removed."
  finish_mount
  ui_print "DONE. Reboot the TV."
  exit 0
  ;;
*)
  ui_print "Unknown mode"; exit 1 ;;
esac
