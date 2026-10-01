#!/usr/bin/env bash
# End-to-end check: play the bundled demo and detect audio on the host sink.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
export LC_ALL=C
source ./audio-env.sh
mkdir -p .run
podman run --rm --pull=never --platform linux/386 --network=none \
    -v "$PWD/out:/out:ro,Z" --entrypoint /out/test-music localhost/doom-runtime
# The shareware demo uses version 109; Linux DOOM expects 110. Its format is
# unchanged. Adapt only this local test fixture, never the IWAD or engine.
python3 - <<'PY'
import struct
from pathlib import Path
wad = Path('wad/doom1.wad').read_bytes()
magic, count, directory = struct.unpack_from('<4sII', wad)
assert magic == b'IWAD'
for index in range(count):
    offset, size, name = struct.unpack_from('<II8s', wad, directory + index * 16)
    if name.rstrip(b'\0') == b'DEMO1':
        demo = bytearray(wad[offset:offset + size])
        assert demo[0] == 109
        demo[0] = 110
        Path('.run/audiodem.lmp').write_bytes(demo)
        break
else:
    raise SystemExit('DEMO1 not found in the shareware IWAD')
PY
sink=${PULSE_SINK:-$(sed -n 's/^Default Sink: //p' <<< "$audio_info")}
[[ -n $sink ]] || { echo 'No default audio sink.' >&2; exit 1; }
# Separate runs ensure music cannot hide broken effects, or vice versa.
for mode in effects music; do
    if [[ $mode == effects ]]; then
        printf 'sfx_volume 8\nmusic_volume 0\n' > .run/audio-check.cfg
    else
        printf 'sfx_volume 0\nmusic_volume 8\n' > .run/audio-check.cfg
    fi
    parec --device="$sink.monitor" --format=s16le --rate=11025 --channels=2 \
        > ".run/$mode-test.raw" &
    recorder=$!
    trap 'kill "$recorder" 2>/dev/null || true' EXIT
    sleep 0.2
    # Upstream reports timedemo completion through I_Error and exits with 255.
    status=0
    bash run.sh -config /save/audio-check.cfg -timedemo audiodem > ".run/$mode-test.log" 2>&1 || status=$?
    kill "$recorder"
    wait "$recorder" || true
    trap - EXIT
    [[ $status == 255 ]] && grep -E '^Error: timed [0-9]+ gametics in [0-9]+ realtics$' ".run/$mode-test.log" || {
        cat ".run/$mode-test.log" >&2; exit 1;
    }
    if grep -Ei 'DOOM audio:|DOOM music:|Could not start sound|error:|segmentation fault' ".run/$mode-test.log" | grep -v '^Error: timed '; then
        exit 1
    fi
    od -An -v -t d2 ".run/$mode-test.raw" |
        awk '{ for (i=1; i<=NF; i++) if ($i != 0) sound=1 } END { exit !sound }' || {
            echo "FAIL: no $mode audio on $sink.monitor" >&2; exit 1;
        }
    echo "PASS: demo completed with audible $mode."
done
