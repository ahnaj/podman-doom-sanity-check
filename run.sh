#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
[[ -x out/linuxxdoom && -x out/sndserver ]] || {
    echo 'Run bash setup.sh first.' >&2; exit 1;
}
[[ -n ${DISPLAY:-} ]] || { echo 'A desktop X11 display (or WSLg) is required.' >&2; exit 1; }
xdpyinfo >/dev/null
pactl info >/dev/null

mkdir -p wad .run
chmod 700 .run
compgen -G 'wad/*.wad' >/dev/null || { echo 'No IWAD; run bash setup.sh.' >&2; exit 1; }

# PulseAudio, PipeWire's PulseAudio service, and WSLg expose a Unix socket.
pulse=${PULSE_SERVER:-unix:${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native}
pulse=${pulse#unix:}
[[ -S $pulse ]] || { echo "No PulseAudio Unix socket at $pulse" >&2; exit 1; }
audio=(-e PULSE_SERVER=unix:/tmp/pulse -v "$pulse:/tmp/pulse")
cookie=${PULSE_COOKIE:-${XDG_CONFIG_HOME:-$HOME/.config}/pulse/cookie}
if [[ -f $cookie ]]; then
    audio+=(-e PULSE_COOKIE=/tmp/pulse-cookie -v "$cookie:/tmp/pulse-cookie:ro")
fi

session=$(mktemp -d "$PWD/.run/session.XXXXXX")
xephyr=
cleanup() {
    [[ -z $xephyr ]] || kill "$xephyr" 2>/dev/null || true
    rm -rf -- "$session"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
display=
for number in {90..110}; do
    if [[ ! -e /tmp/.X${number}-lock && ! -S /tmp/.X11-unix/X${number} ]]; then
        display=:$number
        break
    fi
done
[[ -n $display ]] || { echo 'No free Xephyr display.' >&2; exit 1; }
touch "$session/Xauthority"
xauth -f "$session/Xauthority" add "$display" . "$(mcookie)"
Xephyr "$display" -screen 640x400x8 -nolisten tcp -auth "$session/Xauthority" > "$session/Xephyr.log" 2>&1 &
xephyr=$!
ready=0
for attempt in {1..50}; do
    if XAUTHORITY="$session/Xauthority" xdpyinfo -display "$display" >/dev/null 2>&1; then ready=1; break; fi
    kill -0 "$xephyr" 2>/dev/null || break
    sleep 0.1
done
(( ready )) || { cat "$session/Xephyr.log" >&2; exit 1; }

# Host networking shares the local abstract X11 socket used by WSLg.
# No TCP listener is enabled. Host IPC is needed by the MIT-SHM renderer.
podman run --rm --platform linux/386 --network=host --hostname "$(hostname)" \
    --userns=keep-id --ipc=host --security-opt label=disable \
    -e DISPLAY="$display" -e XAUTHORITY=/tmp/Xauthority "${audio[@]}" \
    -v "$session/Xauthority:/tmp/Xauthority:ro" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    -v "$PWD/out:/out:ro" -v "$PWD/wad:/wad:ro" \
    -v "$PWD/.run:/save" -e HOME=/save -w /save \
    doom-runtime -2 "$@"
