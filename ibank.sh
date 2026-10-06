#!/bin/bash
# Usage: ./ibank.sh [start | save | upgrade | build | export [file] | import <file>]
set -euo pipefail

IMAGE=ibank
NAME=ibanksandbox
PLATFORM=linux/amd64

die() { echo "$*" >&2; exit 1; }
has_image() { [[ -n $(docker images -q "$1") ]]; }

build() {
    docker build --pull --no-cache --platform "$PLATFORM" -t "$IMAGE:base" "$(dirname "$0")"
}

# Boots the sandbox (systemd only, no browser) from the saved identity, or from a fresh one.
boot() {
    local image=$IMAGE:latest
    if ! has_image "$image"; then
        has_image "$IMAGE:base" || build
        image=$IMAGE:base
        echo "No saved identity: creating a new one. Run '$0 save' once the bank has registered this device."
    fi
    if docker inspect "$NAME" &> /dev/null; then
        [[ $(docker inspect -f '{{.State.Running}}' "$NAME") == false ]] || die "$NAME is already running."
        [[ $(docker inspect -f '{{.Config.Image}}' "$NAME") != "$IMAGE:base" ]] \
            || die "$NAME holds a new identity that was never saved: run '$0 save' (or 'docker rm $NAME' to discard it)."
        docker rm "$NAME" > /dev/null
    fi
    docker run -d --privileged --platform "$PLATFORM" --shm-size=2g \
        --tmpfs /run --tmpfs /run/lock --tmpfs /tmp \
        -h "${IBANK_HOSTNAME:-$NAME}" --name "$NAME" "$@" "$image" > /dev/null
    local state
    for _ in {1..60}; do
        [[ $(docker inspect -f '{{.State.Running}}' "$NAME") == true ]] \
            || { docker logs "$NAME" >&2; die "$NAME stopped while booting."; }
        state=$(docker exec "$NAME" systemctl is-system-running 2> /dev/null || true)
        [[ $state == "" || $state == offline || $state == initializing || $state == starting ]] || break
        sleep 1
    done
}

start() {
    local display run_args=() exec_args=()
    if [[ ${IBANK_X11:-} == tcp || $(docker info -f '{{.Name}}' 2> /dev/null) == minikube ]]; then
        # docker runs inside the minikube VM: reach the host X server (XQuartz, VcXsrv) over TCP
        display=$(minikube ssh ip ro sh default | awk '{ print $3":0" }')
        xhost "+$(minikube ip)" &> /dev/null || true
    else
        # local X server (Xorg, XWayland, WSLg): share its socket and a cookie valid for any hostname
        : "${DISPLAY:?DISPLAY is not set}"
        display=$DISPLAY
        run_args+=(-v /tmp/.X11-unix:/tmp/.X11-unix:ro)
        # the cookie must be readable by the sandbox's uid, so it lives in a private (0700) directory
        local cookie xauth
        xauth=${XDG_RUNTIME_DIR:-$(mktemp -d)}/ibank.xauth
        if command -v xauth > /dev/null && cookie=$(xauth nlist "$DISPLAY" 2> /dev/null) && [[ -n $cookie ]]; then
            : > "$xauth"
            sed 's/^..../ffff/' <<< "$cookie" | xauth -f "$xauth" nmerge -
            chmod 644 "$xauth"
            run_args+=(-v "$xauth:/tmp/.Xauthority:ro")
            exec_args+=(-e XAUTHORITY=/tmp/.Xauthority)
        fi
    fi
    boot ${run_args[@]+"${run_args[@]}"}
    docker exec -d --user bankusr -e DISPLAY="$display" -e IBANK_URL="${IBANK_URL:-https://www.bb.com.br}" \
        ${exec_args[@]+"${exec_args[@]}"} "$NAME" browser
}

# Saves the sandbox (identity, chrome profile, warsaw state) as $IMAGE:latest, flattened into a
# single layer: commits would stack a layer per save (overlay2 caps the depth at 128) and keep every
# deleted file, old cookies included, in the exported image.
save() {
    docker inspect "$NAME" &> /dev/null || die "There is no $NAME container to save."
    docker stop -t 30 "$NAME" > /dev/null
    local old changes=() env value
    old=$(docker images -q "$IMAGE:latest")
    changes+=(--change "ENTRYPOINT $(docker inspect -f '{{json .Config.Entrypoint}}' "$NAME")")
    changes+=(--change "CMD $(docker inspect -f '{{json .Config.Cmd}}' "$NAME")")
    changes+=(--change "STOPSIGNAL $(docker inspect -f '{{.Config.StopSignal}}' "$NAME")")
    while IFS= read -r env; do
        [[ -n $env ]] || continue
        value=${env#*=}; value=${value//\\/\\\\}; value=${value//\"/\\\"}; value=${value//\$/\\\$}
        changes+=(--change "ENV ${env%%=*}=\"$value\"")
    done < <(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$NAME")
    docker export "$NAME" | docker import --platform "$PLATFORM" "${changes[@]}" - "$IMAGE:latest" > /dev/null
    docker rm "$NAME" > /dev/null
    [[ -z $old ]] || docker rmi "$old" &> /dev/null || true
    echo "Saved $IMAGE:latest."
}

upgrade() {
    has_image "$IMAGE:latest" || die "No saved identity to upgrade: run '$0 build' for a fresh image."
    boot
    docker exec "$NAME" ibank-install
    save
}

case ${1:-start} in
    start) start ;;
    save) save ;;
    upgrade) upgrade ;;
    build) build ;;
    export)
        has_image "$IMAGE:latest" || die "No saved identity to export."
        file=${2:-$IMAGE-$(date +%F).tar.gz}
        (umask 077 && docker save "$IMAGE:latest" | gzip > "$file")
        echo "Exported to $file. It holds your bank session and device identity: keep it private."
        ;;
    import)
        [[ -n ${2:-} ]] || die "Usage: $0 import <file>"
        docker load -i "$2"
        ;;
    *) die "Usage: $0 [start | save | upgrade | build | export [file] | import <file>]" ;;
esac
