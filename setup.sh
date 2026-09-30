#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

[[ $(uname -m) == x86_64 || $(uname -m) == i686 ]] || {
    echo 'An x86 Linux host with 32-bit execution support is required.' >&2; exit 1;
}
[[ $EUID != 0 ]] || { echo 'Run as your desktop user, not root.' >&2; exit 1; }

# Install only if a required host tool is missing.
missing=0
for tool in podman git curl unzip Xephyr xauth xdpyinfo pactl parec mcookie python3; do
    command -v "$tool" >/dev/null || missing=1
done
if (( missing )); then
    . /etc/os-release
    case "$ID" in
        ubuntu|debian)
            sudo apt-get update
            sudo apt-get install -y ca-certificates curl gnupg
            # Focal predates Podman in Ubuntu's standard repositories.
            if [[ $ID == ubuntu && $VERSION_ID == 20.04 ]] && ! command -v podman >/dev/null; then
                key=$(mktemp)
                trap 'rm -f "$key"' EXIT
                curl -fsSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/Release.key -o "$key"
                sudo gpg --dearmor --batch --yes -o /usr/share/keyrings/libcontainers-archive-keyring.gpg "$key"
                rm -f "$key"
                trap - EXIT
                echo 'deb [signed-by=/usr/share/keyrings/libcontainers-archive-keyring.gpg] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_20.04/ /' |
                    sudo tee /etc/apt/sources.list.d/libcontainers.list >/dev/null
                sudo apt-get update
            fi
            sudo apt-get install -y podman git curl unzip xserver-xephyr xauth x11-utils pulseaudio-utils util-linux python3
            ;;
        *)
            echo 'Install Podman, Git, curl, unzip, Xephyr, xauth, xdpyinfo, pactl, parec, mcookie, and Python 3, then rerun.' >&2
            exit 1
            ;;
    esac
fi
podman info >/dev/null

revision=a77dfb96cb91780ca334d0d4cfd86957558007e0
if [[ ! -e source ]]; then
    git -c core.autocrlf=false clone https://github.com/id-Software/DOOM.git source
    git -C source checkout --detach "$revision"
fi
[[ $(git -C source rev-parse HEAD) == "$revision" ]] || {
    echo "source/ must be at $revision; move it aside or check out that revision." >&2; exit 1;
}
[[ -z $(git -C source status --porcelain --untracked-files=no) ]] || {
    echo 'source/ has local changes; preserve them elsewhere before building.' >&2; exit 1;
}
mkdir -p out
podman build --platform linux/386 --target build -t doom-build -f Containerfile .
podman run --rm --platform linux/386 --network=none --userns=keep-id \
    -v "$PWD/source:/src:ro,Z" -v "$PWD/out:/out:Z" doom-build
podman build --platform linux/386 --target runtime -t doom-runtime -f Containerfile .
for executable in linuxxdoom sndserver; do
    podman run --rm --platform linux/386 --network=none \
        -v "$PWD/out:/out:ro,Z" --entrypoint /lib/ld-linux.so.2 \
        doom-runtime --list "/out/$executable"
done
mkdir -p wad .run
chmod 700 .run
if ! compgen -G 'wad/*.wad' >/dev/null; then
    download=$(mktemp -d .run/shareware.XXXXXX)
    trap 'rm -rf -- "$download"' EXIT
    curl -fL --retry 3 https://www.gamers.org/pub/idgames/idstuff/doom/doom19s.zip -o "$download/doom19s.zip"
    unzip -q "$download/doom19s.zip" 'DOOMS_19.1' 'DOOMS_19.2' -d "$download"
    cat "$download/DOOMS_19.1" "$download/DOOMS_19.2" > "$download/doom.zip"
    unzip -p "$download/doom.zip" DOOM1.WAD > "$download/doom1.wad"
    echo "1d7d43be501e67d927e415e0b8f3e29c3bf33075e859721816f652a526cac771  $download/doom1.wad" | sha256sum -c -
    mv "$download/doom1.wad" wad/doom1.wad
    rm -rf -- "$download"
    trap - EXIT
fi
echo 'Setup complete. Run: bash run.sh'
