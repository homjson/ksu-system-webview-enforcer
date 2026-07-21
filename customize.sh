ui_print "- System WebView Enforcer"
ui_print "- Manual action is enabled from KernelSU Manager"
ui_print "- Boot auto-run is disabled by default"
ui_print "- Edit config/settings.conf and config/apps.conf after install if needed"

PREV_MODDIR="/data/adb/modules/ksu_system_webview_enforcer"
if [ -f "$PREV_MODDIR/config/apps.conf" ]; then
  cp -f "$PREV_MODDIR/config/apps.conf" "$MODPATH/config/apps.conf"
  ui_print "- Preserved existing config/apps.conf"
fi
if [ -f "$PREV_MODDIR/config/settings.conf" ]; then
  cp -f "$PREV_MODDIR/config/settings.conf" "$MODPATH/config/settings.conf"
  ui_print "- Preserved existing config/settings.conf"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/boot-completed.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/lib/webview_enforcer.sh" 0 0 0644
