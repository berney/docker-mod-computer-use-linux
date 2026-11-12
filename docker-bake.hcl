group "default" {
  targets = ["mod"]
}

# Local image. Publish with:
#   docker bake --push --set mod.tags=ghcr.io/<you>/computer-use-linux-mod:0.7.53
target "mod" {
  context    = "."
  dockerfile = "Dockerfile"
  tags       = ["computer-use-linux-mod:dev"]
  # linuxserver's applicator extracts the registry blob with tar xzf.
  output     = ["type=docker,compression=gzip,force-compression=true"]
  args = {
    VERSION = "0.7.53"
  }
}

# Sideload tarball. Some buildx versions will not create a missing export directory.
target "tar" {
  inherits = ["mod"]
  tags     = []
  output   = ["type=tar,dest=computer-use-linux.tar"]
}
