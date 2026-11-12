# syntax=docker/dockerfile:1
# The README's overlay example.
ARG MOD_IMAGE
ARG BASE_IMAGE
FROM ${MOD_IMAGE} AS computer-use-linux-mod
FROM ${BASE_IMAGE}
COPY --link --from=computer-use-linux-mod / /
