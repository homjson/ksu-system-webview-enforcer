#!/system/bin/sh
MODDIR=${0%/*}

LOG_FILE="$MODDIR/logs/uninstall.log"
mkdir -p "$(dirname "$LOG_FILE")"
: > "$LOG_FILE"

. "$MODDIR/lib/webview_enforcer.sh"

unlock_target() {
  package="$1"
  rel="$2"
  base="/data/data/$package"
  target="$base/$rel"

  if ! is_safe_relative_path "$rel"; then
    log "Skip unsafe path: $package | $rel"
    return
  fi

  if [ -d "$target" ]; then
    chmod 0755 "$target" 2>/dev/null
    chown "$(stat -c '%u:%g' "$base" 2>/dev/null || echo 0:0)" "$target" 2>/dev/null
    log "Unlocked placeholder: $target"
  fi
}

# Override library's process_app: unlock instead of block, and process all
# apps regardless of enabled flag (uninstall should clean up everything).
process_app() {
  package="$2"
  targets="$4"

  [ -n "$package" ] || return
  [ -n "$targets" ] || return

  base="/data/data/$package"

  if [ ! -d "$base" ]; then
    return
  fi

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    unlock_target "$package" "$rel"
  done <<EOF
$targets
EOF
}

if [ -f "$APPS_CONF" ]; then
  parse_apps_config
fi

log "Uninstall cleanup finished."
