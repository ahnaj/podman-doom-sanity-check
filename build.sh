#!/bin/sh
set -eu
export LC_ALL=C

# A failed rebuild must not leave an old executable looking successful.
rm -f /out/linuxxdoom /out/sndserver
cp -R /src/linuxdoom-1.10 /tmp/doom
cd /tmp/doom
patch --batch --fuzz=0 -p1 < /usr/local/share/doom/compat.patch
mkdir -p linux
make -B -j1 CFLAGS='-O2 -Wall -std=gnu89 -fcommon -DNORMALUNIX -DLINUX' \
    LDFLAGS= LIBS='-lXext -lX11 -lm'
readelf -h linux/linuxxdoom | grep 'Class:.*ELF32'
readelf -h linux/linuxxdoom | grep 'Machine:.*Intel 80386'
cp -R /src/sndserv /tmp/sndserv
cd /tmp/sndserv
sed -i 's/\r$//' *.[ch] Makefile
patch --batch --fuzz=0 -p1 < /usr/local/share/doom/audio.patch
cp /usr/local/share/doom/audio.c linux.c
mkdir -p linux
make -B -j1 CFLAGS='-O2 -Wall -std=gnu89 -fcommon -DNORMALUNIX -DLINUX' \
    LIBS='-lm -lpulse-simple -lpulse'
readelf -h linux/sndserver | grep 'Machine:.*Intel 80386'
install -m 755 /tmp/doom/linux/linuxxdoom linux/sndserver /out/
sha256sum /out/linuxxdoom /out/sndserver
