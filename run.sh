#!/bin/bash
set -e
[[ -z $(docker images -q ibank:sandbox) ]] && docker build -t ibank:sandbox .
X11SERVER=$(minikube ssh ip ro sh default | awk '{ print $3":0" }')
DOCKERHOST=$(minikube ip)
docker run --privileged -dt --shm-size=2G --rm -h ibanksandbox --name ibanksandbox -e DISPLAY=${X11SERVER} ibank:sandbox
xhost +${DOCKERHOST} &> /dev/null || true
docker exec --user bankusr -d ibanksandbox /bin/bash -c browser
