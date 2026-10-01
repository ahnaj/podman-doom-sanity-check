FROM docker.io/i386/debian:bookworm-slim@sha256:eec2e08d4c6ae5e701c735ef112bfd06730f441e78be405be03ddbec5a7143d2 AS base

# Freeze package resolution as well as the base image and source revision.
RUN rm /etc/apt/sources.list.d/debian.sources \
    && printf '%s\n' \
       'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian/20260920T000000Z bookworm main' \
       'deb [check-valid-until=no] http://snapshot.debian.org/archive/debian-security/20260920T000000Z bookworm-security main' \
       > /etc/apt/sources.list

FROM base AS runtime
RUN apt-get update \
    && apt-get install -y --no-install-recommends libx11-6 libxext6 libpulse0 libsdl2-2.0-0 libwildmidi2 freepats \
    && rm -rf /var/lib/apt/lists/*
ENV DOOMWADDIR=/wad HOME=/tmp
WORKDIR /tmp
ENTRYPOINT ["/out/linuxxdoom"]

FROM base AS build
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc make libc6-dev libxext-dev libpulse-dev libsdl2-dev libwildmidi-dev patch \
    && rm -rf /var/lib/apt/lists/*
COPY compat.patch audio.patch audio.c music.patch music.c test-music.c build.sh /usr/local/share/doom/
ENTRYPOINT ["/bin/sh", "/usr/local/share/doom/build.sh"]
