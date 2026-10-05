#!/bin/bash

set -e

IMAGE_NAME="debbuger-env"
CONTAINER_NAME="building-a-debugger-env"

mkdir -p workspace

docker run --rm -it \
    --name "$CONTAINER_NAME" \
    --hostname "$CONTAINER_NAME" \
    --cap-add=SYS_PTRACE \
    --security-opt seccomp=unconfined \
    -v "$(pwd)/workspace:/workspace" \
    -w /workspace \
    "$IMAGE_NAME" \
    /bin/bash