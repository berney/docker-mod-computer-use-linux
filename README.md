# computer-use-linux linuxserver mod

Adds the `computer-use-linux` MCP server to a linuxserver.io Selkies desktop such as webtop, in X11 or Wayland mode.
The mod is one filesystem layer: two static binaries and an s6 service that starts `computer-use-linux mcp --listen` once the desktop is up.
The desktop image itself stays as it is.
The binaries are Avi Fenesh's [computer-use-linux](https://github.com/agent-sh/computer-use-linux), and the build fetches that release's licence with them into `/usr/share/licenses/computer-use-linux/LICENSE`.

Publish `5200/tcp` on `127.0.0.1` only.
The listener is plain HTTP, and the token is its only check.

## Build

From the repository root:

```sh
docker bake          # image computer-use-linux-mod:dev
docker bake tar      # computer-use-linux.tar, for sideloading
```

The image downloads the upstream musl release (`v0.7.53` by default) and checks the published sha256.
It supports `amd64` and `arm64`.
To build another release, run `VERSION=<release> docker bake`.

## Use it

There are three ways to add the mod.
The first is the one linuxserver.io documents for its own mods.
For a ready-made desktop an agent can drive while you watch, see [`examples/demo`](examples/demo/README.md).

### DOCKER_MODS from a registry

`DOCKER_MODS` downloads only over HTTPS and applies only the first layer of the image, which is why the mod is one layer.
CI publishes the image for amd64 and arm64 as `ghcr.io/berney/docker-mod-computer-use-linux` when a `v*` tag is pushed and the tests pass.
A git tag `v0.7.53` publishes the image tag `0.7.53`, a mod-only fix to the same release is tagged `v0.7.53-1`, and every release also moves `latest`.
Put this in `compose.yml`:

```yaml
services:
  webtop:
    image: lscr.io/linuxserver/webtop:alpine-kde
    environment:
      DOCKER_MODS: ghcr.io/berney/docker-mod-computer-use-linux:0.7.53-1
      COMPUTER_USE_LINUX_MCP_TOKEN: change-me
    ports:
      - 127.0.0.1:3001:3001
      - 127.0.0.1:5200:5200
```

To publish to your own registry, log in and run `IMAGE=<registry>/<name> docker bake --push publish`.

### DOCKER_MODS, sideloaded (no registry)

Use this when the container cannot reach a registry, or to try a local build.
Run `docker bake tar`, then mount the tarball at `/mods/computer-use-linux.tar` and turn on sideloading in the same `compose.yml`:

```yaml
    environment:
      DOCKER_MODS: computer-use-linux
      DOCKER_MODS_SIDELOAD: "true"
      COMPUTER_USE_LINUX_MCP_TOKEN: change-me
    volumes:
      - ./computer-use-linux.tar:/mods/computer-use-linux.tar:ro
```

### Overlay image

Copy the mod into your own image, for example a `baseimage-selkies` app:

```dockerfile
FROM ghcr.io/berney/docker-mod-computer-use-linux:0.7.53-1 AS computer-use-linux-mod
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
The server always accepts `localhost`, `127.0.0.1` and `::1` as the `Host`.
Add any other names clients use, such as a Kubernetes Service name, to `COMPUTER_USE_LINUX_MCP_ALLOWED_HOSTS`.
Use the token file if you can, because a token in `COMPUTER_USE_LINUX_MCP_TOKEN` stays readable in `/proc/<pid>/environ` while the server runs.
Over HTTP, every `get_tree_page` call must pass the `snapshot_id` from the caller's latest `get_app_state`.
So must `click`, `scroll`, `set_value` and `perform_action` calls that pick an element by `element_index` or selector.
Setting `COMPUTER_USE_LINUX_ENABLE_SHELL=1` turns the MCP server off, because the listener refuses to serve `run_shell`.

## Notes

- Keep `PUID` and `PGID` the same as when the `/config` volume was created, or the desktop will not start.
- The mod sets `PIXELFLUX_CU`, `PIXELFLUX_CU_TOKEN` and the accessibility variables when they are unset, so you don't need `PELORUS=true`.
- The service finds the desktop under the launcher Selkies records in `/de-pid`.
  If a process there listens on its own Wayland socket (KWin, labwc or Sway), the server runs on that Wayland desktop; otherwise it runs on X11 (`DISPLAY`), including desktops that run on Xwayland in Wayland mode.
- X11 window control needs `wmctrl`, which the webtop images do not ship.
  The mod adds it through linuxserver's package installer at container start, which needs network access.
  Alpine packages it only in edge/testing, so the Alpine xfce and MATE webtops have screenshots and input but no window control; i3, Sway, labwc and KDE use their own interfaces instead.

  CI checks every Selkies webtop tag in both modes.
  The table shows the window-control backends `doctor` reports; every case also has screenshots and input.

  | Webtop        | X11 (`PIXELFLUX_WAYLAND=false`) | Wayland (`PIXELFLUX_WAYLAND=true`) |
  |---------------|---------------------------------|------------------------------------|
  | `alpine-i3`   | i3                              | i3 (Sway), wlr-foreign-toplevel    |
  | `alpine-kde`  | n/a, no X11 session             | KWin                               |
  | `alpine-mate` | none                            | none (Xwayland)                    |
  | `latest`      | none                            | labwc, wlr-foreign-toplevel        |
  | `arch-i3`     | i3, X11                         | i3 (Sway), wlr-foreign-toplevel    |
  | `arch-kde`    | n/a, no X11 session             | KWin                               |
  | `arch-mate`   | X11                             | X11 (Xwayland)                     |
  | `arch-xfce`   | X11                             | labwc, wlr-foreign-toplevel        |
  | `debian-i3`   | i3                              | i3 (Sway), wlr-foreign-toplevel    |
  | `debian-kde`  | KWin, X11                       | KWin, X11 (Xwayland)               |
  | `debian-mate` | X11                             | X11 (Xwayland)                     |
  | `debian-xfce` | X11                             | X11 (Xwayland)                     |
  | `el-i3`       | i3, X11                         | i3, X11 (Xwayland)                 |
  | `el-mate`     | X11                             | X11 (Xwayland)                     |
  | `el-xfce`     | X11                             | X11 (Xwayland)                     |
  | `fedora-i3`   | i3, X11                         | i3 (Sway), wlr-foreign-toplevel    |
  | `fedora-kde`  | n/a, no X11 session             | KWin                               |
  | `fedora-mate` | X11                             | X11 (Xwayland)                     |
  | `fedora-xfce` | X11                             | X11 (Xwayland)                     |
  | `ubuntu-i3`   | i3                              | i3 (Sway), wlr-foreign-toplevel    |
  | `ubuntu-kde`  | KWin, X11                       | KWin                               |
  | `ubuntu-lxqt` | X11                             | labwc, wlr-foreign-toplevel        |
  | `ubuntu-mate` | X11                             | X11 (Xwayland)                     |
  | `ubuntu-xfce` | X11                             | labwc, wlr-foreign-toplevel        |

  On the `el-*` webtops pixelflux offers no computer-use route, so screenshots go through X11 and input through xdotool.

## Test

Each way of adding the mod has a fixture and a script under `tests/`.
`registry` and `sideload` use `compose.yml` files, and `overlay` uses a `Dockerfile`.
Each script starts a desktop and runs `goss` inside it to check the files and that port 5200 is listening.
It then sends a fixed MCP `initialize`, `tools/list` and `doctor` from the host, and fails unless `doctor` reports a screenshot route, an input route and a window-control backend (`EXPECT_WINDOW_CONTROL=0` drops the last).
You need `goss` on `PATH`, `computer-use-linux-mod:dev`, and the sideload tarball:

```sh
docker bake mod tar
for t in tests/*/test.sh; do "$t"; done
```

CI runs each test as its own job on amd64 and arm64.
It also runs the sideload test on every desktop in the table above, on amd64, with `BASE_IMAGE` and `PIXELFLUX_WAYLAND` set for each:

```sh
BASE_IMAGE=lscr.io/linuxserver/webtop:alpine-i3 PIXELFLUX_WAYLAND=true tests/sideload/test.sh
```

## Licence

Copyright (c) 2026 Berne Campbell.
The files in this repository are licensed under the GNU Affero General Public License v3.0 or later (`AGPL-3.0-or-later`); see `LICENSE`.
If you run a modified version for others over a network, you must offer them its source.
The `computer-use-linux` binaries the image downloads keep their own licence, in `/usr/share/licenses/computer-use-linux/LICENSE`.
