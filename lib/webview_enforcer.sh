CONFIG_DIR="$MODDIR/config"
APPS_CONF="$CONFIG_DIR/apps.conf"
SETTINGS_CONF="$CONFIG_DIR/settings.conf"
LOG_DIR="$MODDIR/logs"

AUTO_RUN_ON_BOOT=0
FORCE_STOP_APPS=1
CLEAR_APP_CACHE=1

init_log() {
  mode="$1"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/$mode.log"
  : > "$LOG_FILE"
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

load_settings() {
  if [ -f "$SETTINGS_CONF" ]; then
    . "$SETTINGS_CONF"
  fi
}

is_safe_relative_path() {
  case "$1" in
    ""|/*|*../*|../*|*"/.."|".")
      return 1
      ;;
  esac
  return 0
}

get_data_owner() {
  path="$1"
  stat -c "%u:%g" "$path" 2>/dev/null || echo "0:0"
}

force_stop_app() {
  package="$1"

  if [ "$FORCE_STOP_APPS" = "1" ]; then
    /system/bin/am force-stop "$package" >/dev/null 2>&1
    log "Force-stopped $package"
  fi
}

is_locked_dir() {
  target="$1"

  if [ ! -d "$target" ]; then
    return 1
  fi

  perms="$(stat -c "%a" "$target" 2>/dev/null)"
  owner="$(stat -c "%u" "$target" 2>/dev/null)"

  if [ "$perms" = "0" ] && [ "$owner" = "0" ]; then
    return 0
  fi

  return 1
}

block_dir() {
  base="$1"
  package="$2"
  rel="$3"

  if ! is_safe_relative_path "$rel"; then
    log "Skip unsafe path: $package | $rel"
    return 1
  fi

  target="$base/$rel"
  parent="${target%/*}"

  if is_locked_dir "$target"; then
    log "Already blocked: $target"
    return 1
  fi

  if [ "$parent" != "$target" ] && [ ! -d "$parent" ]; then
    log "Skip missing parent for $target"
    return 1
  fi

  force_stop_app "$package"
  rm -rf "$target" 2>/dev/null
  mkdir -p "$target" 2>/dev/null
  chown 0:0 "$target" 2>/dev/null
  chmod 000 "$target" 2>/dev/null

  if [ -d "$target" ]; then
    log "Blocked: $target"
    return 0
  else
    log "Failed to block: $target"
    return 1
  fi
}

clear_cache_dirs() {
  base="$1"

  if [ "$CLEAR_APP_CACHE" != "1" ]; then
    return
  fi

  rm -rf "$base"/app_webview "$base"/app_webview_* 2>/dev/null
  rm -rf "$base"/cache/* "$base"/code_cache/* 2>/dev/null
  log "Cleared WebView leftovers and cache under $base"
}

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
    chmod 0771 "$target" 2>/dev/null
    chown "$(stat -c '%u:%g' "$base" 2>/dev/null || echo 0:0)" "$target" 2>/dev/null
    log "Unlocked: $target"
  fi
}

process_app() {
  enabled="$1"
  package="$2"
  label="$3"
  targets="$4"

  case "$enabled" in
    ""|\#*)
      return
      ;;
  esac

  if [ "$enabled" != "1" ] && [ "$enabled" != "2" ]; then
    log "Skip disabled app: $label ($package)"
    return
  fi

  if [ -z "$package" ] || [ -z "$targets" ]; then
    log "Skip invalid config row: $label"
    return
  fi

  base="/data/data/$package"

  if [ ! -d "$base" ]; then
    log "Skip missing app data: $label ($package)"
    return
  fi

  owner="$(get_data_owner "$base")"

  if [ "$enabled" = "2" ]; then
    log "Unlocking $label ($package), data owner $owner"
    while IFS= read -r rel; do
      [ -n "$rel" ] || continue
      unlock_target "$package" "$rel"
    done <<EOF
$targets
EOF
    return
  fi

  log "Processing $label ($package), data owner $owner"
  changed=0

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    if block_dir "$base" "$package" "$rel"; then
      changed=1
    fi
  done <<EOF
$targets
EOF

  if [ "$changed" = "1" ]; then
    clear_cache_dirs "$base"
  else
    log "No changes needed for $label ($package)"
  fi
}

reset_app_config() {
  current_enabled=""
  current_package=""
  current_label=""
  current_targets=""
}

append_target() {
  rel="$1"

  if [ -z "$current_targets" ]; then
    current_targets="$rel"
  else
    current_targets="$current_targets
$rel"
  fi
}

flush_app_config() {
  if [ -n "$current_label" ] || [ -n "$current_package" ] || [ -n "$current_targets" ]; then
    process_app "$current_enabled" "$current_package" "$current_label" "$current_targets"
  fi

  reset_app_config
}

trim_line() {
  echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

parse_config_line() {
  line="$1"

  case "$line" in
    ""|\#*)
      return
      ;;
    *"|"*)
      flush_app_config
      old_ifs="$IFS"
      IFS="|"
      set -- $line
      IFS="$old_ifs"
      old_targets="$4"
      old_targets="$(echo "$old_targets" | sed 's/,/\
/g')"
      process_app "$1" "$2" "$3" "$old_targets"
      return
      ;;
  esac

  key="${line%%[[:space:]]*}"
  value="$(echo "$line" | sed 's/^[^[:space:]]*[[:space:]]*//')"

  case "$key" in
    app)
      flush_app_config
      current_label="$value"
      current_enabled="0"
      ;;
    enabled)
      current_enabled="$value"
      ;;
    package)
      current_package="$value"
      ;;
    dir)
      append_target "$value"
      ;;
    end)
      flush_app_config
      ;;
    *)
      log "Skip unknown config line: $line"
      ;;
  esac
}

parse_apps_config() {
  reset_app_config

  while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    line="$(trim_line "$raw_line")"
    parse_config_line "$line"
  done < "$APPS_CONF"

  flush_app_config
}

run_enforcer() {
  mode="$1"
  init_log "$mode"
  load_settings

  if [ ! -f "$APPS_CONF" ]; then
    log "Missing config: $APPS_CONF"
    exit 1
  fi

  log "System WebView Enforcer started in $mode mode."
  parse_apps_config

  log "System WebView Enforcer finished."
}
