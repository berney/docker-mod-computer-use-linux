#!/usr/bin/env bash
# Retry network commands only, never a test or an entire workflow step.
set -euo pipefail

delay=10
for attempt in {1..5}; do
  if "$@"; then
    exit 0
  else
    status=$?
  fi
  if ((attempt == 5)); then
    exit "$status"
  fi
  wait_seconds=$((delay + RANDOM % 6))
  echo "Command failed (exit $status, attempt $attempt/5); retrying in ${wait_seconds}s: $*" >&2
  sleep "$wait_seconds"
  delay=$((delay * 2))
done
