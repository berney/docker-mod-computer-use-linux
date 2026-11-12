#!/usr/bin/env bash
# DOCKER_MODS with DOCKER_MODS_SIDELOAD and the tarball mounted at /mods.
fixture_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=tests/lib.sh
source "$fixture_dir/../lib.sh"
trap down EXIT

tarball="$repo_dir/computer-use-linux.tar"
if [[ ! -s $tarball ]]; then
  echo "missing $tarball; run docker bake tar first" >&2
  exit 1
fi
down
compose up -d
check_webtop
echo "ok sideload"
