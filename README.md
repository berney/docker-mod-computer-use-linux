# computer-use-linux linuxserver mod

Adds the `computer-use-linux` MCP server to a linuxserver.io Selkies desktop (webtop, chrome, or anything built on `baseimage-selkies`).
The mod is a single-layer filesystem: two static binaries and an s6 service that starts `computer-use-linux mcp --listen` once the desktop is up.
It does not replace the desktop image.
The binaries are Avi Fenesh's [computer-use-linux](https://github.com/agent-sh/computer-use-linux); the build fetches that release's licence with them and puts it at `/usr/share/licenses/computer-use-linux/LICENSE`.

Publish `5200/tcp` on `127.0.0.1` only.
The listener is plain HTTP and the token is its only check.

## Build

From the repository root:

```sh
docker bake          # image computer-use-linux-mod:dev
docker bake tar      # computer-use-linux.tar, for sideloading
```

The image downloads the upstream musl release (`v0.7.53` by default) and checks the published sha256.
`amd64` and `arm64` are the supported architectures.
Pass another release with `docker bake --set mod.args.VERSION=0.7.53`.

## Test

Each way to use the mod has a fixture and a script under `tests/`: `sideload` and `registry` are `compose.yml` files, and `overlay` is a `Dockerfile`.
Each script starts a desktop, runs `goss` inside it to check the files and that port 5200 is listening, then sends a fixed MCP `initialize` and `tools/list` from the host.
You need `goss` on `PATH` and `computer-use-linux-mod:dev` built:

```sh
docker bake
for t in tests/*/test.sh; do "$t"; done
```

CI runs each test as its own job on amd64 and arm64.

## Use it

Pick one of three ways.

### DOCKER_MODS, sideloaded (no registry)

Put this in `compose.yml`.
Mount the tarball at `/mods/computer-use-linux.tar` and turn on sideloading:

```yaml
services:
  webtop:
    image: lscr.io/linuxserver/webtop:alpine-kde
    environment:
      DOCKER_MODS: computer-use-linux
      DOCKER_MODS_SIDELOAD: "true"
      COMPUTER_USE_LINUX_MCP_TOKEN: change-me
    volumes:
      - ./computer-use-linux.tar:/mods/computer-use-linux.tar:ro
    ports:
      - 127.0.0.1:3001:3001
      - 127.0.0.1:5200:5200
```

### DOCKER_MODS from a registry

`DOCKER_MODS` downloads only over HTTPS and applies only the first layer of the image, which is why the mod is one layer.
Push the image to a registry you control, then set `DOCKER_MODS` in the same `compose.yml`:

```sh
docker bake --push --set mod.tags=ghcr.io/<you>/computer-use-linux-mod:0.7.53
```

```yaml
    environment:
      DOCKER_MODS: ghcr.io/<you>/computer-use-linux-mod:0.7.53
```

### Overlay image

Copy the mod into your own image, for example a `baseimage-selkies` app:

```dockerfile
FROM computer-use-linux-mod:dev AS computer-use-linux-mod
FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie
COPY --link --from=computer-use-linux-mod / /
```

## Environment

| Variable                               | Required          | Default                                                       |
|----------------------------------------|-------------------|---------------------------------------------------------------|
| `COMPUTER_USE_LINUX_MCP_TOKEN_FILE`    | this or the token | unset; path to a file holding the bearer token (preferred)    |
| `COMPUTER_USE_LINUX_MCP_TOKEN`         | this or the file  | unset; with neither set the MCP server is disabled            |
| `COMPUTER_USE_LINUX_MCP_LISTEN`        | no                | `0.0.0.0:5200`                                                |
| `COMPUTER_USE_LINUX_MCP_ALLOWED_HOSTS` | no                | the container's hostname; comma- or space-separated hostnames |
| `COMPUTER_USE_LINUX_INDICATOR`         | no                | `0`. Set `1` to show the on-screen indicator                  |

Clients send `Authorization: Bearer <token>` to `http://127.0.0.1:5200/mcp`.
`localhost`, `127.0.0.1` and `::1` are always allowed as the `Host`; add the names other clients use, such as a Kubernetes Service name, to `COMPUTER_USE_LINUX_MCP_ALLOWED_HOSTS`.
Prefer the token file: a token in `COMPUTER_USE_LINUX_MCP_TOKEN` stays readable in `/proc/<pid>/environ` while the server runs.
Over HTTP, `click`, `scroll`, `set_value` and `perform_action` calls that pick an element by `element_index` or selector, and every `get_tree_page` call, must pass the `snapshot_id` from the caller's latest `get_app_state`.
`COMPUTER_USE_LINUX_ENABLE_SHELL=1` disables the MCP server, because the listener refuses to serve `run_shell`.

## Notes

- Don't set `PUID`/`PGID` to a different value from the one that created an existing `/config` volume; the desktop will not start.
- The mod also sets `PIXELFLUX_CU`, `PIXELFLUX_CU_TOKEN` and the accessibility variables when they are unset, so `PELORUS=true` is not needed.

## Licence

Copyright (c) 2026 Berne Campbell.
The files in this repository are licensed under the GNU Affero General Public License v3.0 or later (`AGPL-3.0-or-later`); see `LICENSE`.
If you run a modified version for others over a network, you must offer them its source.
The `computer-use-linux` binaries the image downloads keep their own licence, shipped at `/usr/share/licenses/computer-use-linux/LICENSE`.
