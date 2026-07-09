#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include <math.h>
#include <string.h>
#include <algorithm>
#include <atomic>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

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
static std::atomic<float> crossfade_progress(1.0f);
static std::atomic<float> crossfade_step(0.0f);
static std::atomic<bool> active_is_A(true);

// Position State
static std::atomic<int64_t> seek_target_frame(-1);
static std::atomic<float> current_position(0.0f);
static std::atomic<float> current_duration(0.0f);

// Normalization State
static std::atomic<bool> norm_enabled(false);
static std::atomic<float> target_db(-14.0f);
static float current_gain = 1.0f;

// Stereo Width / Mono State
static std::atomic<float> stereo_width(1.0f);
static std::atomic<bool> mono_enabled(false);

// EQ State
struct BiquadCoeffs {
    float b0, b1, b2, a1, a2;
};

struct BiquadState {
    float x1 = 0, x2 = 0, y1 = 0, y2 = 0;
};

static const float EQ_FREQS[10] = {32.0f, 64.0f, 125.0f, 250.0f, 500.0f, 1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f};
static std::atomic<float> eq_gains[10];
static BiquadCoeffs eq_coeffs[10];
static BiquadState eq_states[10][2]; // 10 bands, 2 channels

static void calculate_peaking_eq(int index, float gainDb, float sampleRate) {
    float A = powf(10.0f, gainDb / 40.0f);
    float w0 = 2.0f * (float)M_PI * EQ_FREQS[index] / sampleRate;
    float alpha = sinf(w0) / (2.0f * 1.414f); // Q = 1.414

    float b0 = 1.0f + alpha * A;
    float b1 = -2.0f * cosf(w0);
    float b2 = 1.0f - alpha * A;
    float a0 = 1.0f + alpha / A;
    float a1 = -2.0f * cosf(w0);
    float a2 = 1.0f - alpha / A;

    eq_coeffs[index].b0 = b0 / a0;
    eq_coeffs[index].b1 = b1 / a0;
    eq_coeffs[index].b2 = b2 / a0;
    eq_coeffs[index].a1 = a1 / a0;
    eq_coeffs[index].a2 = a2 / a0;
}

static inline float process_biquad(float in, int band, int channel) {
    BiquadCoeffs& c = eq_coeffs[band];
    BiquadState& s = eq_states[band][channel];
    
    float out = c.b0 * in + c.b1 * s.x1 + c.b2 * s.x2 - c.a1 * s.y1 - c.a2 * s.y2;
    
    // Denormal prevention
    if (fabs(out) < 1e-15f) out = 0.0f;
    
    s.x2 = s.x1;
    s.x1 = in;
    s.y2 = s.y1;
    s.y1 = out;
    
    return out;
}

// Limiter state
static float limiter_gain = 1.0f;

static inline float db_to_linear(float db) {
    return powf(10.0f, db / 20.0f);
}

// Custom Data Callback for DSP Pipeline
void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    float* pOutputF32 = (float*)pOutput;
    ma_uint32 channels = pDevice->playback.channels;
    
    // Handle Thread-Safe Seek
    int64_t seek_target = seek_target_frame.exchange(-1);
    if (seek_target >= 0) {
        ma_decoder* pActive = active_is_A.load() ? &decoderA : &decoderB;
        bool loaded = active_is_A.load() ? isA_loaded.load() : isB_loaded.load();
        if (loaded) {
            ma_decoder_seek_to_pcm_frame(pActive, seek_target);
        }
    }

    // 1. Read sources
    float bufferA[16384]; // Max supported frames: 8192
    ma_uint64 framesReadA = 0;
    if (isA_loaded && isA_playing) {
        ma_decoder_read_pcm_frames(&decoderA, bufferA, frameCount, &framesReadA);
    }
    
    float bufferB[16384];
    ma_uint64 framesReadB = 0;
    if (isB_loaded && isB_playing) {
        ma_decoder_read_pcm_frames(&decoderB, bufferB, frameCount, &framesReadB);
    }
    
    // Broadcast current position
    ma_decoder* pCurrent = active_is_A.load() ? &decoderA : &decoderB;
    bool curLoaded = active_is_A.load() ? isA_loaded.load() : isB_loaded.load();
    if (curLoaded) {
        ma_uint64 cursor = 0;
        ma_decoder_get_cursor_in_pcm_frames(pCurrent, &cursor);
        current_position.store((float)cursor / 44100.0f);
    }
    
    // 2. Mix and Crossfade (Pass 1)
    float fade_prog = crossfade_progress.load();
    float fade_step = crossfade_step.load();
    bool crossfading = is_crossfading.load();
    bool a_is_main = active_is_A.load();
    
    float sumSquares = 0.0f;
    
    for (ma_uint32 f = 0; f < frameCount; ++f) {
        if (crossfading) {
            fade_prog += fade_step;
            if (fade_prog >= 1.0f) {
                fade_prog = 1.0f;
                crossfading = false;
                is_crossfading.store(false);
                if (a_is_main) isB_playing.store(false);
                else isA_playing.store(false);
            }
            crossfade_progress.store(fade_prog);
        }
        
        float gainA = crossfading ? (a_is_main ? fade_prog : 1.0f - fade_prog) : (a_is_main ? 1.0f : 0.0f);
        float gainB = crossfading ? (a_is_main ? 1.0f - fade_prog : fade_prog) : (a_is_main ? 0.0f : 1.0f);
        
        float L = ((f < framesReadA) ? bufferA[f * channels + 0] : 0.0f) * gainA + 
                  ((f < framesReadB) ? bufferB[f * channels + 0] : 0.0f) * gainB;
                  
        float R = ((f < framesReadA) ? bufferA[f * channels + 1] : 0.0f) * gainA + 
                  ((f < framesReadB) ? bufferB[f * channels + 1] : 0.0f) * gainB;
                  
        pOutputF32[f * channels + 0] = L;
        pOutputF32[f * channels + 1] = R;
        
        sumSquares += L * L + R * R;
    }
    
    // 3. RMS Calculation
    float target_gain = 1.0f;
    bool is_norm_enabled = norm_enabled.load();
    if (is_norm_enabled) {
        float rms = sqrtf(sumSquares / (float)(frameCount * channels));
        float target_linear = db_to_linear(target_db.load());
        target_gain = (rms > 0.0001f) ? (target_linear / rms) : 1.0f;
    } else {
        current_gain = 1.0f;
    }

    // 4. Update EQ Coeffs (in case they changed from Dart thread)
    static float last_eq_gains[10] = {0};
    for (int b = 0; b < 10; ++b) {
        float g = eq_gains[b].load();
        if (g != last_eq_gains[b]) {
            calculate_peaking_eq(b, g, (float)pDevice->sampleRate);
            last_eq_gains[b] = g;
        }
    }

    // 5. Apply Gain, EQ, Stereo Width, and Limiter (Pass 2)
    bool is_mono = mono_enabled.load();
    float width = stereo_width.load();
    float slew_rate = 0.001f; 
    
    for (ma_uint32 f = 0; f < frameCount; ++f) {
        float L = pOutputF32[f * channels + 0];
        float R = pOutputF32[f * channels + 1];
        
        // Slew-rate Normalization Gain
        if (is_norm_enabled) {
            if (current_gain < target_gain) {
                current_gain += slew_rate;
                if (current_gain > target_gain) current_gain = target_gain;
            } else if (current_gain > target_gain) {
                current_gain -= slew_rate;
                if (current_gain < target_gain) current_gain = target_gain;
            }
            L *= current_gain;
            R *= current_gain;
        }
        
        // 10-Band EQ
        for (int b = 0; b < 10; ++b) {
            L = process_biquad(L, b, 0);
            R = process_biquad(R, b, 1);
        }
        
        // Stereo Width / Mono Matrix
        if (is_mono) {
            float avg = (L + R) * 0.5f;
            L = avg;
            R = avg;
        } else if (width != 1.0f) {
            float mid = (L + R) * 0.5f;
            float side = (L - R) * 0.5f;
            side *= width;
            L = mid + side;
            R = mid - side;
        }
        
        // Limiter (Fast attack, moderate release)
        float peakL = fabs(L);
        float peakR = fabs(R);
        float maxPeak = (peakL > peakR) ? peakL : peakR;
        
        if (maxPeak * limiter_gain > 1.0f) {
            limiter_gain = 1.0f / maxPeak; // Instant attack
        } else {
            limiter_gain += 0.00005f; // Release
            if (limiter_gain > 1.0f) limiter_gain = 1.0f;
        }
        
        L *= limiter_gain;
        R *= limiter_gain;
        
        // Final Hard Clamp
        if (L > 1.0f) L = 1.0f; else if (L < -1.0f) L = -1.0f;
        if (R > 1.0f) R = 1.0f; else if (R < -1.0f) R = -1.0f;
        
        pOutputF32[f * channels + 0] = L;
        pOutputF32[f * channels + 1] = R;
    }
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int init_audio_engine() {
    if (is_engine_initialized) return 0;
    
    // Initialize EQ defaults
    for(int i=0; i<10; i++) {
        eq_gains[i].store(0.0f);
        calculate_peaking_eq(i, 0.0f, 44100.0f);
    }
    
    ma_device_config deviceConfig = ma_device_config_init(ma_device_type_playback);
    deviceConfig.playback.format   = ma_format_f32;
    deviceConfig.playback.channels = 2;
    deviceConfig.sampleRate        = 44100;
    deviceConfig.dataCallback      = data_callback;

    if (ma_device_init(NULL, &deviceConfig, &device) != MA_SUCCESS) return -1;
    ma_device_start(&device);
    
    is_engine_initialized = true;
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int load_audio_file(const char* path) {
    if (!is_engine_initialized) return -1;
    if (isA_loaded.load()) ma_decoder_uninit(&decoderA);
    ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 2, 44100);
    if (ma_decoder_init_file(path, &config, &decoderA) != MA_SUCCESS) return -1;
    
    ma_uint64 length = 0;
    ma_decoder_get_length_in_pcm_frames(&decoderA, &length);
    current_duration.store((float)length / 44100.0f);
    
    isA_loaded.store(true);
    active_is_A.store(true);
    is_crossfading.store(false);
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int play_audio() {
    if (!is_engine_initialized) return -1;
    if (active_is_A.load()) isA_playing.store(true);
    else isB_playing.store(true);
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
    if (isA_loaded.load()) { ma_decoder_uninit(&decoderA); isA_loaded.store(false); }
    if (isB_loaded.load()) { ma_decoder_uninit(&decoderB); isB_loaded.store(false); }
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void set_normalization_target(float target) { target_db.store(target); }

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void enable_normalization(bool enable) { norm_enabled.store(enable); }

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int crossfade_to_file(const char* path, int duration_ms) {
    if (!is_engine_initialized) return -1;
    bool load_into_B = active_is_A.load();
    ma_decoder* pNext = load_into_B ? &decoderB : &decoderA;
    if (load_into_B && isB_loaded.load()) { ma_decoder_uninit(&decoderB); isB_loaded.store(false); }
    else if (!load_into_B && isA_loaded.load()) { ma_decoder_uninit(&decoderA); isA_loaded.store(false); }
    
    ma_decoder_config config = ma_decoder_config_init(ma_format_f32, 2, 44100);
    if (ma_decoder_init_file(path, &config, pNext) != MA_SUCCESS) return -1;
    
    ma_uint64 length = 0;
    ma_decoder_get_length_in_pcm_frames(pNext, &length);
    current_duration.store((float)length / 44100.0f);
    
    if (load_into_B) { isB_loaded.store(true); isB_playing.store(true); }
    else { isA_loaded.store(true); isA_playing.store(true); }
    
    float frames = (duration_ms / 1000.0f) * 44100.0f;
    crossfade_step.store(frames > 0.0f ? (1.0f / frames) : 1.0f);
    crossfade_progress.store(0.0f);
    active_is_A.store(!load_into_B);
    is_crossfading.store(true);
    return 0;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void set_eq_band_gain(int band_index, float gain_db) {
    if (band_index >= 0 && band_index < 10) {
        eq_gains[band_index].store(gain_db);
    }
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void set_stereo_width(float width) {
    stereo_width.store(width);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
void set_mono(bool enable) {
    mono_enabled.store(enable);
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
float get_duration() {
    return current_duration.load();
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
float get_position() {
    return current_position.load();
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
int seek_to_position(float position_seconds) {
    if (!is_engine_initialized) return -1;
    ma_uint64 target_frame = (ma_uint64)(position_seconds * 44100.0f);
    seek_target_frame.store((int64_t)target_frame);
    return 0;
}
