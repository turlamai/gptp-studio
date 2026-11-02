#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/wait-app-exit.sh"

bash -c 'exit 0' &
wait_for_clean_app_exit "$!" 2

bash -c 'exit 7' &
failed_pid=$!
if wait_for_clean_app_exit "$failed_pid" 2; then
  echo 'nonzero exit incorrectly accepted' >&2
  exit 1
fi

bash -c 'kill -TERM "$$"' &
signaled_pid=$!
if wait_for_clean_app_exit "$signaled_pid" 2; then
  echo 'signal termination incorrectly accepted' >&2
  exit 1
fi

sleep 1 &
live_pid=$!
if wait_for_clean_app_exit "$live_pid" 0; then
  echo 'live process incorrectly accepted' >&2
  exit 1
fi
kill -0 "$live_pid"
wait "$live_pid"
echo 'clean-exit gate: success, nonzero/signal rejection and live-process timeout PASS'
