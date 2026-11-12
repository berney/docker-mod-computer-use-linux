# syntax=docker/dockerfile:1
# Trust the test registry's self-signed certificate.
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
COPY --link certs/cert.pem /usr/local/share/ca-certificates/mod-test-registry.crt
RUN update-ca-certificates
