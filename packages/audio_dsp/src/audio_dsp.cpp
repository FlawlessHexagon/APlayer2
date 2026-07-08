#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

static ma_engine engine;
static ma_sound sound;
static bool is_engine_initialized = false;
static bool is_sound_loaded = false;

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int init_audio_engine() {
    if (is_engine_initialized) return 0;
    
    ma_result result = ma_engine_init(NULL, &engine);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    is_engine_initialized = true;
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int load_audio_file(const char* path) {
    if (!is_engine_initialized) return -1;
    
    if (is_sound_loaded) {
        ma_sound_uninit(&sound);
        is_sound_loaded = false;
    }
    
    ma_result result = ma_sound_init_from_file(&engine, path, 0, NULL, NULL, &sound);
    if (result != MA_SUCCESS) {
        return (int)result;
    }
    is_sound_loaded = true;
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int play_audio() {
    if (!is_sound_loaded) return -1;
    ma_result result = ma_sound_start(&sound);
    return (result == MA_SUCCESS) ? 0 : (int)result;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int pause_audio() {
    if (!is_sound_loaded) return -1;
    ma_result result = ma_sound_stop(&sound);
    return (result == MA_SUCCESS) ? 0 : (int)result;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int shutdown_audio_engine() {
    if (is_sound_loaded) {
        ma_sound_uninit(&sound);
        is_sound_loaded = false;
    }
    if (is_engine_initialized) {
        ma_engine_uninit(&engine);
        is_engine_initialized = false;
    }
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used)) 
int test_ffi_connection() {
    return 42;
}
