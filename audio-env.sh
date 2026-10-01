#!/usr/bin/env bash
# Sourced by the launcher and audio check so both use the same host server.
if [[ -z ${PULSE_SERVER:-} ]]; then
    for socket in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/pulse/native" /mnt/wslg/PulseServer; do
        if [[ -S $socket ]] && PULSE_SERVER="unix:$socket" pactl info >/dev/null 2>&1; then
            export PULSE_SERVER="unix:$socket"
            break
        fi
    done
    if ! pactl info >/dev/null 2>&1; then
        # Start an installed desktop service without changing its configuration.
        systemctl --user start pipewire-pulse.service 2>/dev/null ||
            systemctl --user start pulseaudio.socket 2>/dev/null ||
            pulseaudio --start 2>/dev/null || true
    fi
fi
audio_info=$(LC_ALL=C pactl info) || {
    echo 'Cannot connect to desktop audio. On Windows 11, enable/update WSLg (wsl --update in PowerShell) and reopen Ubuntu. On Linux, start PulseAudio or pipewire-pulse.' >&2
    exit 1
}
pulse=$(sed -n 's/^Server String: //p' <<< "$audio_info")
pulse=${pulse#unix:}
[[ $pulse == /* && -S $pulse ]] || {
    echo "A local PulseAudio Unix socket is required; server is: $pulse" >&2
    exit 1
}
export PULSE_SERVER="unix:$pulse"
