#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/../.." && pwd)
podman run --rm --pull=never --entrypoint /bin/bash \
  -v "$repo_dir/root/etc/s6-overlay/s6-rc.d/init-mod-computer-use-linux-add-package/run:/package-hook:ro,Z" \
  "${BASE_IMAGE:-lscr.io/linuxserver/webtop:alpine-mate}" -euo pipefail -c '
  ! command -v wmctrl
  cp /etc/apk/repositories /tmp/repositories.before
  bash /package-hook
  test "$(cat /mod-repo-packages-to-install.list)" = "wmctrl@testing"
  cmp /tmp/repositories.before /etc/apk/repositories
  apk add --no-cache $(cat /mod-repo-packages-to-install.list)
  apk add --no-cache --simulate curl
  cmp /tmp/repositories.before /etc/apk/repositories

  Xvfb :99 -screen 0 1024x768x24 >/tmp/xvfb.log 2>&1 &
  export DISPLAY=:99
  for attempt in {1..50}; do
    if xdpyinfo >/dev/null 2>&1; then break; fi
    sleep 0.1
  done
  marco --replace >/tmp/marco.log 2>&1 &
  for attempt in {1..50}; do
    if wmctrl -m >/tmp/wmctrl.out 2>&1; then break; fi
    sleep 0.1
  done
  cat /tmp/wmctrl.out
  grep -q "^Name: .*Marco" /tmp/wmctrl.out

  rm /etc/apk/repositories.d/computer-use-linux.list /mod-repo-packages-to-install.list
  bash /package-hook
  test ! -e /etc/apk/repositories.d/computer-use-linux.list
  test ! -e /mod-repo-packages-to-install.list
  cmp /tmp/repositories.before /etc/apk/repositories
'
