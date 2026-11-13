#!/usr/bin/env bash
# Retry policy: recover transient failures, stop on success, preserve exhaustion status.
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export work

# Skip wall-clock waits, but record the requested backoff.
sleep() { printf '%s\n' "$1" >> "$work/sleeps"; }
export -f sleep

operation() {
  local attempt=0
  if [[ -f $work/attempts ]]; then read -r attempt < "$work/attempts"; fi
  attempt=$((attempt + 1))
  printf '%s\n' "$attempt" > "$work/attempts"
  ((attempt >= $1)) || return 42
  printf '%s\n' "$2" > "$work/result"
}
export -f operation

retry() { bash "$repo_dir/scripts/retry.sh" bash -c 'operation "$@"' _ "$@"; }

retry 1 'argument with spaces'
test "$(cat "$work/attempts")" = 1
test "$(cat "$work/result")" = 'argument with spaces'
test ! -e "$work/sleeps"

rm "$work/attempts" "$work/result"
retry 3 recovered
test "$(cat "$work/attempts")" = 3
test "$(cat "$work/result")" = recovered
mapfile -t delays < "$work/sleeps"
test "${#delays[@]}" = 2
((delays[0] >= 10 && delays[0] <= 15 && delays[1] >= 20 && delays[1] <= 25))

rm "$work/attempts" "$work/result" "$work/sleeps"
status=0
retry 99 unreachable || status=$?
test "$status" = 42
test "$(cat "$work/attempts")" = 5
test ! -e "$work/result"
mapfile -t delays < "$work/sleeps"
test "${#delays[@]}" = 4
((delays[2] >= 40 && delays[2] <= 45 && delays[3] >= 80 && delays[3] <= 85))
echo 'ok retry'
