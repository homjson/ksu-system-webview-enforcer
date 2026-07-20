#!/system/bin/sh
MODDIR=${0%/*}

. "$MODDIR/lib/webview_enforcer.sh"

echo "Running System WebView Enforcer..."
run_enforcer "manual"

echo "Done. Log:"
tail -n 40 "$MODDIR/logs/manual.log" 2>/dev/null
