#!/usr/bin/env bash
# Copy the mod layer into a desktop image with a Dockerfile.
fixture_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=tests/lib.sh
source "$fixture_dir/../lib.sh"
trap down EXIT

down
compose up -d --build
check_webtop
echo "ok overlay"
