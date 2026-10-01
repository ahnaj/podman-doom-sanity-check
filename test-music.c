/* Offline music regression check, using SDL's dummy audio device. */
#include <assert.h>
#include <stdarg.h>
#include <SDL2/SDL.h>
#define SDL_AudioInit(driver) SDL_AudioInit("dummy")
#include "music.c"
int snd_MusicVolume = 8;
void I_Error(char *format, ...)
{
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    exit(1);
}
int main(void)
{
    unsigned char song[] = {
        'M','U','S',26, 16,0, 16,0, 1,0, 0,0, 0,0, 0,0,
        0x40, 0, 0, 0x10, 0xbc, 100, 0x9f, 0xa3, 100, 14, 0x00, 60, 0x8f, 35, 1, 0x60
    };
    unsigned char original[sizeof song], buffer[4096];
    int i, j, audible = 0;
    memcpy(original, song, sizeof song);
    for (j = 0; j < 2; j++) {
        audible = 0;
        I_RegisterSong(song, sizeof song);
        assert(!memcmp(song, original, sizeof song));
        I_PlaySong(1, 0);
        I_PauseSong(1);
        assert(SDL_GetAudioDeviceStatus(music_device) == SDL_AUDIO_PAUSED);
        for (i = 0; i < 100; i++) {
            int k;
            music_output(NULL, buffer, sizeof buffer);
            for (k = 0; k < sizeof buffer; k++) audible |= buffer[k];
        }
        assert(audible && !I_QrySongPlaying(1));
        I_PlaySong(1, 1);
        I_PauseSong(1);
        for (i = 0; i < 100; i++) music_output(NULL, buffer, sizeof buffer);
        assert(I_QrySongPlaying(1));
        I_SetMusicVolume(0);
        music_output(NULL, buffer, sizeof buffer);
        for (i = 0; i < sizeof buffer; i++) assert(buffer[i] == 0);
        I_SetMusicVolume(8);
        I_ResumeSong(1);
        assert(SDL_GetAudioDeviceStatus(music_device) == SDL_AUDIO_PLAYING);
        I_StopSong(1);
        assert(!I_QrySongPlaying(1));
        I_UnRegisterSong(1);
        assert(!music_song);
    }
    I_ShutdownMusic();
    I_ShutdownMusic();
    puts("PASS: music renders, ends, loops, pauses, resumes, mutes, and preserves song data on replay.");
    return 0;
}
