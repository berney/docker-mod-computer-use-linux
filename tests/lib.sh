# shellcheck shell=bash
# Sets repo_dir and push_flags for the test scripts; they set fixture_dir before sourcing.
# shellcheck disable=SC2034,SC2154
# Shared by tests/*/test.sh: start a fixture with compose, then check the
# running desktop with goss and one hardcoded MCP exchange.
set -euo pipefail

tests_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(dirname "$tests_dir")
export BASE_IMAGE=${BASE_IMAGE:-lscr.io/linuxserver/webtop:alpine-kde}
export MOD_IMAGE=${MOD_IMAGE:-computer-use-linux-mod:dev}
export COMPUTER_USE_LINUX_MCP_TOKEN=${COMPUTER_USE_LINUX_MCP_TOKEN:-mod-install-test-token}
export MCP_PORT=${MCP_PORT:-15200}

if ! goss=$(command -v "${GOSS:-goss}"); then
  echo "goss is not on PATH" >&2
  exit 1
fi
if ! docker image inspect "$MOD_IMAGE" >/dev/null; then
  echo "missing image $MOD_IMAGE; run docker bake first" >&2
  exit 1
fi

# podman pushes OCI manifests by default, and /docker-mods asks only for
# Docker v2 manifests, so the registry would answer 404.
push_flags=()
if docker info 2>/dev/null | grep -qi podman; then
  push_flags=(--format v2s2)
fi

compose() {
  docker compose -f "$fixture_dir/compose.yml" "$@"
}

down() {
  compose down -v --remove-orphans >/dev/null 2>&1 || true
}

wait_for_mcp() {
  for _ in $(seq 1 90); do
    if curl -fsS -o /dev/null -m 2 "http://127.0.0.1:${MCP_PORT}/mcp" \
      -H "Authorization: Bearer ${COMPUTER_USE_LINUX_MCP_TOKEN}" \
      -H 'Content-Type: application/json' \
      -H 'Accept: application/json, text/event-stream' \
      -d '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"wait","version":"0"}}}' \
      2>/dev/null
    then
      return 0
    fi
    sleep 2
  done
  echo "MCP did not answer on 127.0.0.1:${MCP_PORT}" >&2
  compose logs --tail 40 webtop >&2 || true
  return 1
}

check_webtop() {
  local id
  id=$(compose ps -q webtop)
  wait_for_mcp
  docker cp "$goss" "$id":/tmp/goss
  docker cp "$tests_dir/goss.yaml" "$id":/tmp/goss.yaml
  docker exec "$id" /tmp/goss -g /tmp/goss.yaml validate
  MCP_URL="http://127.0.0.1:${MCP_PORT}/mcp" "$tests_dir/mcp-ping.py"
}
