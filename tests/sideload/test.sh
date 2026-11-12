#!/usr/bin/env bash
# DOCKER_MODS with DOCKER_MODS_SIDELOAD and the tarball mounted at /mods.
fixture_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=tests/lib.sh
source "$fixture_dir/../lib.sh"
trap down EXIT

(cd "$repo_dir" && docker bake tar)
down
compose up -d
check_webtop
echo "ok sideload"
