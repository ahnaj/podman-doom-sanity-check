/* Play the IWAD's MUS/MIDI music with packaged instruments and PulseAudio. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <SDL2/SDL.h>
#include <wildmidi_lib.h>
#include "i_system.h"
#include "i_sound.h"

static SDL_AudioDeviceID music_device;
static midi *music_song;
static int music_playing;

static void music_output(void *unused, Uint8 *buffer, int length)
{
    int count;
    (void)unused;
    memset(buffer, 0, length);
    if (!music_song || !music_playing) return;
    count = WildMidi_GetOutput(music_song, (int8_t *)buffer, length);
    if (count <= 0) {
        if (count < 0)
            fprintf(stderr, "DOOM music: %s\n", WildMidi_GetError());
        music_playing = 0;
    }
}

void I_InitMusic(void)
{
    SDL_AudioSpec format;
    if (music_device) return;
    if (WildMidi_Init("/etc/timidity/freepats.cfg", 22050, 0) < 0)
        I_Error("DOOM music: %s", WildMidi_GetError());
    if (SDL_AudioInit("pulseaudio") < 0)
        I_Error("DOOM music: %s", SDL_GetError());
    SDL_zero(format);
    format.freq = 22050;
    format.format = AUDIO_S16SYS;
    format.channels = 2;
    format.samples = 512;
    format.callback = music_output;
    music_device = SDL_OpenAudioDevice(NULL, 0, &format, NULL, 0);
    if (!music_device) I_Error("DOOM music: %s", SDL_GetError());
    atexit(I_ShutdownMusic);
    I_SetMusicVolume(snd_MusicVolume);
}

void I_ShutdownMusic(void)
{
    if (!music_device) return;
    SDL_CloseAudioDevice(music_device);
    music_device = 0;
    if (music_song) WildMidi_Close(music_song);
    music_song = NULL;
    music_playing = 0;
    WildMidi_Shutdown();
    SDL_AudioQuit();
}

void I_SetMusicVolume(int volume)
{
    /* The original menu uses 0..15, with a legacy call setting 127 first. */
    snd_MusicVolume = volume < 0 ? 0 : volume > 15 ? 15 : volume;
    if (!music_device) return;
    SDL_LockAudioDevice(music_device);
    WildMidi_MasterVolume(snd_MusicVolume * 127 / 15);
    SDL_UnlockAudioDevice(music_device);
}

int I_RegisterSong(void *data, int length)
{
    unsigned char *copy;
    I_InitMusic();
    I_UnRegisterSong(1);
    if (length <= 0) I_Error("DOOM music: empty song");
    /* WildMIDI 0.4.3 remaps MUS percussion channels in the input buffer. */
    copy = malloc(length);
    if (!copy) I_Error("DOOM music: out of memory");
    memcpy(copy, data, length);
    music_song = WildMidi_OpenBuffer(copy, length);
    free(copy);
    if (!music_song) I_Error("DOOM music: %s", WildMidi_GetError());
    return 1;
}

void I_PlaySong(int handle, int looping)
{
    (void)handle;
    if (!music_song) return;
    SDL_PauseAudioDevice(music_device, 1);
    if (WildMidi_SongSeek(music_song, 0) < 0 ||
        WildMidi_SetOption(music_song, WM_MO_LOOP, looping ? WM_MO_LOOP : 0) < 0)
        I_Error("DOOM music: %s", WildMidi_GetError());
    music_playing = 1;
    SDL_PauseAudioDevice(music_device, 0);
}

void I_PauseSong(int handle)
{
    (void)handle;
    if (music_device) SDL_PauseAudioDevice(music_device, 1);
}

void I_ResumeSong(int handle)
{
    (void)handle;
    if (music_device && music_song) SDL_PauseAudioDevice(music_device, 0);
}

void I_StopSong(int handle)
{
    I_PauseSong(handle);
    music_playing = 0;
}

void I_UnRegisterSong(int handle)
{
    I_StopSong(handle);
    if (music_song) WildMidi_Close(music_song);
    music_song = NULL;
}

int I_QrySongPlaying(int handle)
{
    int playing;
    (void)handle;
    if (!music_device) return 0;
    SDL_LockAudioDevice(music_device);
    playing = music_playing;
    SDL_UnlockAudioDevice(music_device);
    return playing;
}
