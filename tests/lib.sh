# shellcheck shell=bash
# Sets repo_dir and push_mod for the test scripts; they set fixture_dir before sourcing.
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

# /docker-mods asks registries only for a Docker v2 manifest or an index.
# podman and Docker 29 (containerd image store) push a single OCI manifest,
# which the registry then refuses with 404, so push Docker v2 explicitly.
push_mod() {
  local ref=$1
  if docker info 2>/dev/null | grep -qi podman; then
    docker tag "$MOD_IMAGE" "$ref"
    docker push --format v2s2 "$ref"
  else
    skopeo copy --format v2s2 --dest-tls-verify=false \
      "docker-daemon:$MOD_IMAGE" "docker://$ref"
  fi
}

compose() {
  local files=(-f "$fixture_dir/compose.yml")
  if [[ -n ${PIXELFLUX_WAYLAND:-} ]]; then
    files+=(-f "$tests_dir/wayland.yml")
  fi
  docker compose "${files[@]}" "$@"
}

mod_logs() {
  compose logs webtop 2>&1 | grep -E 'mod-init|pkg-install|computer-use-linux' >&2 || true
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
  mod_logs
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
  if ! MCP_URL="http://127.0.0.1:${MCP_PORT}/mcp" "$tests_dir/mcp-ping.py"; then
    mod_logs
    return 1
  fi
}
