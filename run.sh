#!/bin/bash
set -e
docker build -t ibank:sandbox .
docker run --privileged -dt --shm-size=2G --rm --name ibanksandbox -e DISPLAY=host.docker.internal:0 ibank:sandbox
xhost +127.0.0.1 &> /dev/null || true
docker exec --user bankusr -d ibanksandbox /bin/bash -c browser
