#!/usr/bin/env bash
# DOCKER_MODS pulling the mod from an HTTPS registry.
fixture_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=tests/lib.sh
source "$fixture_dir/../lib.sh"
certs="$fixture_dir/certs"
cleanup() {
  compose --profile webtop down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$certs"
}
trap cleanup EXIT

cleanup
mkdir -p "$certs"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout "$certs/key.pem" -out "$certs/cert.pem" \
  -subj /CN=registry.test \
  -addext subjectAltName=DNS:registry.test,IP:127.0.0.1 >/dev/null 2>&1
chmod a+r "$certs"/*.pem

compose up -d registry
for _ in $(seq 1 30); do
  curl -fsS --cacert "$certs/cert.pem" https://127.0.0.1:5050/v2/ >/dev/null 2>&1 && break
  sleep 0.5
done
# podman reads the CA from here; Docker and skopeo skip TLS checks for this push.
ca_dir="${XDG_CONFIG_HOME:-$HOME/.config}/containers/certs.d/127.0.0.1:5050"
mkdir -p "$ca_dir"
cp "$certs/cert.pem" "$ca_dir/ca.crt"
push_mod 127.0.0.1:5050/computer-use-linux-mod:test

compose --profile webtop up -d --build webtop
check_webtop
echo "ok registry"
