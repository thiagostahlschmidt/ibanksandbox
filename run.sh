#!/bin/bash
set -e
[[ -z $(docker images -q ibank:sandbox) ]] && docker build -t ibank:sandbox .
docker run --privileged -dt --shm-size=2G --rm -h ibanksandbox --name ibanksandbox -e DISPLAY=host.docker.internal:0 ibank:sandbox
xhost +127.0.0.1 &> /dev/null || true
docker exec --user bankusr -d ibanksandbox /bin/bash -c browser
