#!/usr/bin/env bash
# Run Trivy (open-source scanner, Apache-2.0) from its container: nothing to install, no account.
# It reads local images through the Docker socket and keeps its vulnerability database in a volume.
#   ./labs/security/trivy.sh image shopkart-api:small
exec docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v trivy-cache:/root/.cache \
  -v "$PWD:/work" -w /work \
  aquasec/trivy:0.76.2 "$@"
