#!/system/bin/sh
MODDIR=${0%/*}

. "$MODDIR/lib/webview_enforcer.sh"

load_settings

if [ "$AUTO_RUN_ON_BOOT" = "1" ]; then
  run_enforcer "boot"
else
  init_log "boot"
  log "Boot auto-run is disabled. Set AUTO_RUN_ON_BOOT=1 in config/settings.conf to enable it."
fi
