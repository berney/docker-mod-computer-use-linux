# computer-use-linux demo

Run a KDE desktop in a container, open it in your browser, and let an agent drive it through the [computer-use-linux](https://github.com/agent-sh/computer-use-linux) MCP server.
Pelorus is not needed.

The container is the stock `lscr.io/linuxserver/webtop:alpine-kde` image.
At start it downloads the computer-use-linux docker mod from [`ghcr.io/berney/docker-mod-computer-use-linux`](https://github.com/berney/docker-mod-computer-use-linux) through `DOCKER_MODS`.
The mod adds two static binaries and an s6 service.
At boot the service finds the desktop session, turns on accessibility, and starts `computer-use-linux mcp --listen`.
Screenshots, clicks, keys and typed text go through the desktop's own pixelflux server, so nothing asks for permission.
The compose file turns on the on-screen indicator (`COMPUTER_USE_LINUX_INDICATOR=1`), so whoever is watching sees each action: a pill naming the agent, a moving cursor, click ripples, keycaps and typed text.
The indicator hides itself before every screenshot the agent takes.
Set it to `0` to turn it off.

## Before you start

You need Docker (or podman with `docker compose`), and the container needs to reach `ghcr.io` when it starts.
Run every command below in this directory, `examples/demo`.
To move to a newer mod, change the tag on `DOCKER_MODS` in `docker-compose.yml`.

## Start the desktop

1. Create a token:

   ```sh
   cp .env.example .env
   sed -i "s/^COMPUTER_USE_LINUX_MCP_TOKEN=.*/COMPUTER_USE_LINUX_MCP_TOKEN=$(openssl rand -hex 32)/" .env
   ```

2. Start it:

   ```sh
   docker compose up -d
   ```

3. Open <https://localhost:3101> and accept the self-signed certificate.

The MCP server listens on `http://127.0.0.1:5200/mcp` about 10 seconds after the desktop appears.

## Connect oh-my-pi

`.omp/mcp.json` already defines a server called `webtop`.
It reads the token from your environment, so load `.env` before starting omp in this directory:

```sh
set -a; . ./.env; set +a
omp
```

Check `/mcp list` shows `webtop`, then ask for something like "use webtop: open Chromium and go to ifconfig.me".

Any other MCP client works the same way: streamable HTTP at `http://127.0.0.1:5200/mcp` with `Authorization: Bearer <token>`.

## Ports

| Port   | What                   | Bound to    |
|--------|------------------------|-------------|
| `3101` | Selkies web desktop    | `0.0.0.0`   |
| `5200` | computer-use-linux MCP | `127.0.0.1` |

The desktop is open to your LAN so you can watch from another machine at `https://<host>:3101`.
It has no login, so anyone on the LAN can see and drive it.
The MCP port stays on loopback because it is plain HTTP whose only check is the token; agents run on this host.

## Stop and clean up

```sh
docker compose down        # keeps the desktop's home volume
docker compose down -v     # also deletes it
```

## Known limits

- Element clicks and scrolls at display scale 2 are untested; open the desktop at 100% zoom on a normal-DPI screen for now.
- Chromium shows a first-run terms dialog and a sign-in screen; accept or dismiss them once.
- Two agents on one desktop will type over each other.
