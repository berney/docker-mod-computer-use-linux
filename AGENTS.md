# computer-use-linux linuxserver mod

A one-layer image that adds the computer-use-linux MCP server to a linuxserver.io Selkies desktop.
The desktop image stays stock.
This repo does not build the Rust program.

## Development rules

Load the `developer-grimoire:grimoire` skill before any development work, and follow it.
Also adhere to its companion skills: superpowers, ponytail, humanizer, and i-have-adhd.

Grimoire sections for this project (a section not listed keeps its default):

- Project records: off
- Web services: off
- Work tracking: off
- Cloud: off

## Layout

| Path              | What it is                                                                                      |
|-------------------|-------------------------------------------------------------------------------------------------|
| `Dockerfile`      | Downloads the upstream musl release, checks the sha256, and copies `root/` into a scratch image |
| `docker-bake.hcl` | `mod` local image, `tar` sideload tarball, `publish` multi-arch push to ghcr.io                 |
| `root/`           | s6 service files applied onto the desktop image                                                 |
| `README.md`       | The three ways to apply the mod                                                                 |
| `tests/`          | One fixture and `test.sh` per install path; `lib.sh`, `goss.yaml` and `mcp-ping.py` are shared  |
| `examples/demo/`  | A watched KDE desktop an agent drives over MCP; its own `AGENTS.md` adds the demo rules         |

## Project rules

- Keep the published image to one layer.
  `DOCKER_MODS` applies only the first layer.
- Download `computer-use-linux`, `computer-use-linux-indicator` and the upstream `LICENSE` from the agent-sh `v${VERSION}` tag inside the image build, and check the binaries' published sha256.
  Do not compile them here, and do not vendor the licence: MIT requires the notice of the release we ship.
- The `VERSION` build arg in the Dockerfile and `docker-bake.hcl` names the same release.
- The final stage is `scratch`.
  The fetch stage may be Alpine, because the build needs curl.
- Use `COPY --link`.
- Scripts the image runs live under `root/` or next to the Dockerfile.
  Do not build on the host and copy the result in.
- Never commit `computer-use-linux.tar`, a token, or a built image.
- The listener is plain HTTP.
  Tell people to publish port 5200 on `127.0.0.1` only.
- `/config`, `PUID` and `PGID` belong to linuxserver Selkies images.
  This mod does not invent them.
- Each README install path (registry pull, sideload tar, Dockerfile `COPY`) has a fixture under `tests/`, and a change to one changes the other.
- `examples/demo` only uses the published image; keep it free of build steps and test fixtures.
- A change to how the image is applied updates the README in the same commit.
