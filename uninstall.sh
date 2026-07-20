#!/system/bin/sh
MODDIR=${0%/*}
CONFIG="$MODDIR/config/apps.conf"
LOG_DIR="$MODDIR/logs"
LOG_FILE="$LOG_DIR/uninstall.log"

mkdir -p "$LOG_DIR"
: > "$LOG_FILE"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

is_safe_relative_path() {
  case "$1" in
    ""|/*|*../*|../*|*"/.."|".")
      return 1
      ;;
  esac
  return 0
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
    chmod 0755 "$target" 2>/dev/null
    chown "$(stat -c '%u:%g' "$base" 2>/dev/null || echo 0:0)" "$target" 2>/dev/null
    log "Unlocked placeholder: $target"
  fi
}

reset_app_config() {
  current_package=""
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
  if [ -z "$current_package" ] || [ -z "$current_targets" ]; then
    reset_app_config
    return
  fi

  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    unlock_target "$current_package" "$rel"
  done <<EOF
$current_targets
EOF

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
      package="$2"
      old_targets="$(echo "$4" | sed 's/,/\
/g')"
      while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        unlock_target "$package" "$rel"
      done <<EOF
$old_targets
EOF
      return
      ;;
  esac

  key="${line%%[[:space:]]*}"
  value="$(echo "$line" | sed 's/^[^[:space:]]*[[:space:]]*//')"

  case "$key" in
    app)
      flush_app_config
      reset_app_config
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
  esac
}

if [ -f "$CONFIG" ]; then
  reset_app_config

  while IFS= read -r raw_line || [ -n "$raw_line" ]; do
    line="$(trim_line "$raw_line")"
    parse_config_line "$line"
  done < "$CONFIG"

  flush_app_config
fi

log "Uninstall cleanup finished."
