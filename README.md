# Linux DOOM in Podman

Build and play id Software's original Linux DOOM with rootless Podman.
The engine runs in a 32-bit container, Xephyr provides its 8-bit X11 display,
and the original sound mixer outputs effects through PulseAudio.

## Quick start

```sh
git clone https://github.com/ahnaj/podman-doom-sanity-check.git
cd podman-doom-sanity-check
bash setup.sh
bash run.sh
```

Run as your normal desktop user. Setup installs missing dependencies on
Ubuntu/Debian using `sudo`, fetches the pinned source from
[id Software](https://github.com/id-Software/DOOM), builds both images, and
downloads the checksum-verified DOOM 1.9 shareware IWAD if `wad/` is empty.
The first setup needs internet access; subsequent gameplay runs locally.
Ubuntu 20.04 requires the libcontainers package repository, which setup adds
with a repository-specific signing key.

Requirements: x86 Linux with 32-bit execution support, an X11 desktop or
WSLg, and a running PulseAudio or PipeWire PulseAudio service. Other Linux
distributions can use the scripts after installing the host tools listed
by `setup.sh`. Headless sessions need a graphical desktop first.

## Play

```sh
bash run.sh -warp 1 1       # start E1M1
bash run.sh -skill 4        # Ultra-Violence
```

Arrow keys move, Ctrl fires, Space opens doors, and Esc opens the menu.
Ctrl+Shift toggles Xephyr's keyboard/mouse grab. Quit through DOOM's menu;
the launcher closes its display afterward. Saves and configuration live
in `.run/`.

For the full game, place your own legally obtained `doom.wad`, `doomu.wad`,
or `doom2.wad` in `wad/` before setup. Use one IWAD at a time. Sound effects
work; music is not implemented in the released Linux source.

## Check

```sh
bash test.sh
```

With the shareware `wad/doom1.wad`, this plays a demo and verifies nonzero
samples on the host audio monitor. Keep other audio quiet during the check.
It adapts the demo's version byte in a temporary copy; the IWAD is unchanged.
Build, display, and audio were tested with rootless Podman 3.4.2 on
Ubuntu 20.04 under WSL2.

If audio fails, check `pactl info`. The launcher uses `PULSE_SERVER` or the
standard user socket; WSLg's `/mnt/wslg/PulseServer` is supported. If the
display fails, check `xdpyinfo` in the same terminal.

## Repository

Only scripts, container definitions, and compatibility changes belong in
Git. `source/`, `out/`, `wad/`, and `.run/` are ignored; they contain downloaded
source, binaries, game data, saves, and temporary credentials.

The source revision, base image, and Debian package snapshot are pinned.
Compilation runs offline against a temporary source copy. The patches fix
modern compiler compatibility, X11 palette installation, and sound-server
startup/loading; `audio.c` replaces its obsolete OSS output.

The game container shares host networking and IPC for local X11/MIT-SHM,
and mounts the host audio socket. Xephyr disables TCP listening and uses
an authorization cookie. SELinux container labeling is disabled for this
local desktop session. Game data and executables are mounted read-only.

No upstream source or WAD is distributed in this repository. Upstream code
and game data remain subject to their respective licenses; see the fetched
`source/LICENSE.TXT` and the shareware distribution's terms.
