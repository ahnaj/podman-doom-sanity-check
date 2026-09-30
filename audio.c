/* PulseAudio output for the upstream DOOM sound server. */
#include <stdio.h>
#include <stdlib.h>
#include <pulse/simple.h>
#include <pulse/error.h>

static pa_simple *stream;

static void fail(int error)
{
    fprintf(stderr, "DOOM audio: %s\n", pa_strerror(error));
    exit(1);
}

void I_InitSound(int samplerate, int samplesize)
{
    pa_sample_spec format = { PA_SAMPLE_S16LE, samplerate, 2 };
    pa_buffer_attr buffer = { (uint32_t)-1, 4096, (uint32_t)-1,
                             (uint32_t)-1, (uint32_t)-1 };
    int error;
    (void)samplesize;
    stream = pa_simple_new(NULL, "DOOM", PA_STREAM_PLAYBACK, NULL,
                           "Sound effects", &format, NULL, &buffer, &error);
    if (!stream) fail(error);
}

void I_SubmitOutputBuffer(void *samples, int samplecount)
{
    int error;
    if (pa_simple_write(stream, samples, samplecount * 4, &error) < 0)
        fail(error);
}

void I_ShutdownSound(void)
{
    pa_simple_free(stream);
}

void I_InitMusic(void) {}
void I_ShutdownMusic(void) {}
