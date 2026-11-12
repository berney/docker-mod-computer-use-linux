# computer-use-linux demo

A KDE webtop container with the computer-use-linux docker mod, so an agent can drive a real desktop over MCP while a person watches in the browser.
The repository's root `AGENTS.md` applies here too; this file adds the rules for driving the demo desktop.

## Layout

| Path                 | What it is                                                                      |
|----------------------|---------------------------------------------------------------------------------|
| `docker-compose.yml` | The `webtop` service: stock webtop with the published mod through `DOCKER_MODS` |
| `.omp/mcp.json`      | Project MCP server `webtop` for oh-my-pi                                        |
| `.env.example`       | Template for `.env`, which holds `COMPUTER_USE_LINUX_MCP_TOKEN`                 |

## Demo rules

- The desktop port `3101` is published on all interfaces so it can be watched over the LAN; it has no login.
  The MCP port `5200` stays on `127.0.0.1`: it is plain HTTP protected only by the bearer token.
- The token lives in `.env` and nowhere else in the repo; never commit it, print it, or put it in a URL.
- The `webtop` MCP server controls the container's desktop, not the host.
  Do not use omp's built-in `computer` prelude for this demo; it drives the host.
- Start each desktop task with the `webtop` `get_app_state` tool, and run one agent against the desktop at a time.
- Pass the `snapshot_id` from your latest `get_app_state` with every `click`, `scroll`, `set_value` or `perform_action` that names an `element_index` or selector, and with `get_tree_page`; over HTTP the server refuses those calls without it.
  A refusal saying the snapshot was replaced means another `get_app_state` ran; call it again.
- The mod comes from `ghcr.io/berney/docker-mod-computer-use-linux`, pinned by tag on `DOCKER_MODS` in `docker-compose.yml`.
  It is built and tested at the repository root; the demo only uses the published image.
  After changing the tag, run `docker compose up -d` in this directory to recreate the container.
