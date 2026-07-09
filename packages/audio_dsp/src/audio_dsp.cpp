#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include <math.h>
#include <string.h>
#include <algorithm>
#include <atomic>

// DSP State
static ma_device device;
static bool is_engine_initialized = false;

// Decoders for Dual-Stream
static ma_decoder decoderA;
static std::atomic<bool> isA_loaded(false);
static std::atomic<bool> isA_playing(false);

static ma_decoder decoderB;
static std::atomic<bool> isB_loaded(false);
static std::atomic<bool> isB_playing(false);

// Crossfade State
static std::atomic<bool> is_crossfading(false);
static std::atomic<float> crossfade_progress(1.0f); // 0.0 to 1.0. 1.0 means B is fully active, or A is fully active.
static std::atomic<float> crossfade_step(0.0f);
static std::atomic<bool> active_is_A(true); // true = A is main, false = B is main

// Normalization State
static std::atomic<bool> norm_enabled(false);
static std::atomic<float> target_db(-14.0f);
static float current_gain = 1.0f; // Slew-limited gain

static inline float db_to_linear(float db) {
    return powf(10.0f, db / 20.0f);
}

static inline float linear_to_db(float linear) {
    if (linear <= 0.00001f) return -100.0f;
    return 20.0f * log10f(linear);
}

// Custom Data Callback for DSP Pipeline
void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    float* pOutputF32 = (float*)pOutput;
    ma_uint32 channels = pDevice->playback.channels;
    
    // Clear output buffer first
    memset(pOutputF32, 0, frameCount * channels * sizeof(float));
    
    // Read from A
    float bufferA[16384]; // Max expected frame count usually < 4096
    ma_uint64 framesReadA = 0;
    if (isA_loaded && isA_playing) {
        ma_decoder_read_pcm_frames(&decoderA, bufferA, frameCount, &framesReadA);
    }
    
    // Read from B
    float bufferB[16384];
    ma_uint64 framesReadB = 0;
    if (isB_loaded && isB_playing) {
        ma_decoder_read_pcm_frames(&decoderB, bufferB, frameCount, &framesReadB);
    }
    
    // Mix and Crossfade
    float fade_prog = crossfade_progress.load();
    float fade_step = crossfade_step.load();
    bool crossfading = is_crossfading.load();
    bool a_is_main = active_is_A.load();
    
    for (ma_uint32 i = 0; i < frameCount * channels; ++i) {
        // Handle crossfade per frame (though typically done per sample, doing it per sample channel is fine as long as we step every frame)
        if (i % channels == 0 && crossfading) {
            fade_prog += fade_step;
            if (fade_prog >= 1.0f) {
                fade_prog = 1.0f;
                crossfading = false;
                is_crossfading.store(false);
                if (a_is_main) {
                    isB_playing.store(false); // B faded out entirely
                } else {
                    isA_playing.store(false); // A faded out entirely
                }
            }
            crossfade_progress.store(fade_prog);
        }
        
        float sampleA = (i < framesReadA * channels) ? bufferA[i] : 0.0f;
        float sampleB = (i < framesReadB * channels) ? bufferB[i] : 0.0f;
        
        float gainA = 0.0f;
        float gainB = 0.0f;
        
        if (crossfading) {
            if (a_is_main) {
                // Fading from B to A
                gainA = fade_prog;
                gainB = 1.0f - fade_prog;
            } else {
                // Fading from A to B
                gainA = 1.0f - fade_prog;
                gainB = fade_prog;
            }
        } else {
            if (a_is_main) {
                gainA = 1.0f;
                gainB = 0.0f;
            } else {
                gainA = 0.0f;
                gainB = 1.0f;
            }
        }
        
        float mixed = (sampleA * gainA) + (sampleB * gainB);
        pOutputF32[i] = mixed;
    }
    
    // RMS Normalization Stage
    if (norm_enabled.load()) {
        float sumSquares = 0.0f;
        for (ma_uint32 i = 0; i < frameCount * channels; ++i) {
            sumSquares += pOutputF32[i] * pOutputF32[i];
        }
        float rms = sqrtf(sumSquares / (float)(frameCount * channels));
        
        float target_linear = db_to_linear(target_db.load());
        float target_gain = 1.0f;
        if (rms > 0.0001f) {
            target_gain = target_linear / rms;
        }
        
        // Slew rate limiting (smooth gain changes to avoid clicks)
        float slew_rate = 0.001f; 
        
        for (ma_uint32 i = 0; i < frameCount * channels; ++i) {
            if (i % channels == 0) {
                if (current_gain < target_gain) {
                    current_gain += slew_rate;
                    if (current_gain > target_gain) current_gain = target_gain;
                } else if (current_gain > target_gain) {
                    current_gain -= slew_rate;
                    if (current_gain < target_gain) current_gain = target_gain;
                }
            }
            pOutputF32[i] *= current_gain;
        }
    } else {
        // Reset gain safely when disabled
        current_gain = 1.0f;
    }
    
    // Hard Limiter / Clipping handler (Input Mixer clipping)
    for (ma_uint32 i = 0; i < frameCount * channels; ++i) {
        if (pOutputF32[i] > 1.0f) pOutputF32[i] = 1.0f;
        else if (pOutputF32[i] < -1.0f) pOutputF32[i] = -1.0f;
    }
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int init_audio_engine() {
    if (is_engine_initialized) return 0;
    
    ma_device_config deviceConfig = ma_device_config_init(ma_device_type_playback);
    deviceConfig.playback.format   = ma_format_f32;
    deviceConfig.playback.channels = 2;
    deviceConfig.sampleRate        = 44100;
    deviceConfig.dataCallback      = data_callback;
    deviceConfig.pUserData         = NULL;

    if (ma_device_init(NULL, &deviceConfig, &device) != MA_SUCCESS) {
        return -1;
    }
    
    ma_device_start(&device);
    is_engine_initialized = true;
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int load_audio_file(const char* path) {
    if (!is_engine_initialized) return -1;
    
    if (isA_loaded.load()) {
        ma_decoder_uninit(&decoderA);
    }
    
    ma_decoder_config decoderConfig = ma_decoder_config_init(ma_format_f32, 2, 44100);
    if (ma_decoder_init_file(path, &decoderConfig, &decoderA) != MA_SUCCESS) {
        return -1;
    }
    
    isA_loaded.store(true);
    active_is_A.store(true);
    is_crossfading.store(false);
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int play_audio() {
    if (!is_engine_initialized) return -1;
    if (active_is_A.load()) {
        isA_playing.store(true);
    } else {
        isB_playing.store(true);
    }
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int pause_audio() {
    if (!is_engine_initialized) return -1;
    isA_playing.store(false);
    isB_playing.store(false);
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int shutdown_audio_engine() {
    if (is_engine_initialized) {
        ma_device_uninit(&device);
        is_engine_initialized = false;
    }
    if (isA_loaded.load()) {
        ma_decoder_uninit(&decoderA);
        isA_loaded.store(false);
    }
    if (isB_loaded.load()) {
        ma_decoder_uninit(&decoderB);
        isB_loaded.store(false);
    }
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void set_normalization_target(float target) {
    target_db.store(target);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void enable_normalization(bool enable) {
    norm_enabled.store(enable);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int crossfade_to_file(const char* path, int duration_ms) {
    if (!is_engine_initialized) return -1;
    
    bool load_into_B = active_is_A.load();
    ma_decoder* pNextDecoder = load_into_B ? &decoderB : &decoderA;
    
    if (load_into_B && isB_loaded.load()) {
        ma_decoder_uninit(&decoderB);
        isB_loaded.store(false);
    } else if (!load_into_B && isA_loaded.load()) {
        ma_decoder_uninit(&decoderA);
        isA_loaded.store(false);
    }
    
    ma_decoder_config decoderConfig = ma_decoder_config_init(ma_format_f32, 2, 44100);
    if (ma_decoder_init_file(path, &decoderConfig, pNextDecoder) != MA_SUCCESS) {
        return -1;
    }
    
    if (load_into_B) {
        isB_loaded.store(true);
        isB_playing.store(true);
    } else {
        isA_loaded.store(true);
        isA_playing.store(true);
    }
    
    float frames_total = (duration_ms / 1000.0f) * 44100.0f;
    float step = frames_total > 0.0f ? (1.0f / frames_total) : 1.0f;
    
    crossfade_step.store(step);
    crossfade_progress.store(0.0f);
    active_is_A.store(!load_into_B); // Switch the active track
    is_crossfading.store(true);
    
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used)) 
int test_ffi_connection() {
    return 42;
}
