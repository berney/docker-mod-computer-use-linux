variable "VERSION" {
  default = "0.7.53"
}

variable "IMAGE" {
  default = "ghcr.io/berney/docker-mod-computer-use-linux"
}

# Set by CI to the commit being published; adds an immutable tag.
variable "GIT_SHA" {
  default = ""
}

group "default" {
  targets = ["mod"]
}

# Local image.
target "mod" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["computer-use-linux-mod:dev"]
  # linuxserver's applicator extracts the registry blob with tar xzf.
  output = ["type=docker,compression=gzip,force-compression=true"]
  args = {
    VERSION = VERSION
  }
}

# Sideload tarball. Some buildx versions will not create a missing export directory.
target "tar" {
  inherits = ["mod"]
  tags     = []
  output   = ["type=tar,dest=computer-use-linux.tar"]
}

# Multi-arch image for DOCKER_MODS, pushed by CI from main.
target "publish" {
  inherits  = ["mod"]
  platforms = ["linux/amd64", "linux/arm64"]
  tags = compact([
    "${IMAGE}:latest",
    "${IMAGE}:${VERSION}",
    GIT_SHA != "" ? "${IMAGE}:${VERSION}-${substr(GIT_SHA, 0, 7)}" : "",
  ])
  labels = {
    "org.opencontainers.image.source"   = "https://github.com/berney/docker-mod-computer-use-linux"
    "org.opencontainers.image.licenses" = "AGPL-3.0-or-later"
  }
  annotations = [
    "index:org.opencontainers.image.source=https://github.com/berney/docker-mod-computer-use-linux",
    "index:org.opencontainers.image.licenses=AGPL-3.0-or-later",
  ]
  output = ["type=registry,compression=gzip,force-compression=true"]
}
