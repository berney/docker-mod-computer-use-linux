# syntax=docker/dockerfile:1

# One layer: DOCKER_MODS applies only the first layer of a mod image.
FROM alpine:3.22 AS fetch
ARG VERSION=0.7.53
ARG TARGETARCH
RUN apk add --no-cache curl ca-certificates \
 && if [ -z "${TARGETARCH}" ]; then \
      case "$(uname -m)" in \
        x86_64) TARGETARCH=amd64 ;; \
        aarch64) TARGETARCH=arm64 ;; \
        *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
      esac; \
    fi \
 && case "${TARGETARCH}" in \
      amd64) rust_arch=x86_64 ;; \
      arm64) rust_arch=aarch64 ;; \
      *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && base="https://github.com/agent-sh/computer-use-linux/releases/download/v${VERSION}" \
 && mkdir -p /tmp/dl /out/usr/local/bin \
 && cd /tmp/dl \
 && for name in computer-use-linux computer-use-linux-indicator; do \
      asset="${name}-${rust_arch}-unknown-linux-musl"; \
      curl -fsSL -O "${base}/${asset}"; \
      curl -fsSL -O "${base}/${asset}.sha256"; \
      sha256sum -c "${asset}.sha256"; \
      install -m 755 "${asset}" "/out/usr/local/bin/${name}"; \
    done \
 && mkdir -p /out/usr/share/licenses/computer-use-linux \
 && curl -fsSL -o /out/usr/share/licenses/computer-use-linux/LICENSE \
      "https://raw.githubusercontent.com/agent-sh/computer-use-linux/v${VERSION}/LICENSE"
COPY --link root/ /out/
RUN chmod -R a+rX,go-w /out

FROM scratch
COPY --link --from=fetch /out/ /
