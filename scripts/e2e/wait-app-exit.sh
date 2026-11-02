#!/usr/bin/env bash
# Source in the shell that owns the application child. Never signal it here.
wait_for_clean_app_exit() {
  local pid="$1" seconds="$2" remaining code
  case "$pid:$seconds" in *[!0-9:]*|:*|*:) return 1 ;; esac
  [[ "$pid" -gt 0 && "$seconds" -le 600 ]] || return 1
  remaining=$((seconds * 10))
  while kill -0 "$pid" 2>/dev/null; do
    if [[ "$remaining" -le 0 ]]; then
      printf 'application did not exit normally within %s seconds\n' "$seconds" >&2
      return 1
    fi
    sleep 0.1
    remaining=$((remaining - 1))
  done
  if wait "$pid"; then
    return 0
  else
    code=$?
    printf 'application exit was not clean: %s\n' "$code" >&2
    return 1
  fi
}
