# Development Phase 0 — The Atomic Layer
## Detailed Implementation Plan

*Prepared July 8, 2026*

*Phase 0 establishes the most technically risky component of the APlayer rebuild: the cross-platform native audio DSP layer. There is no complex UI, no state management, and no playlist sync in this phase. The sole objective is to prove that a single, unified audio processing pipeline can be controlled from Dart and executed natively via FFI on both macOS and Android.*

---

## Guiding Principles for Phase 0

1. **DSP Isolation:** The audio signal chain must be implemented in a native language (C/C++) and exposed to Flutter via `dart:ffi`. Flutter plugins should only be used for high-level OS integration (like background audio services), not for digital signal processing.
2. **No UI Dependencies:** The audio engine must be fully testable with a bare-bones debug interface. Do not begin building the premium UI until the audio foundation is solid.
3. **Cross-Platform Parity:** The engine must compile and run identically on both macOS and Android from day one.

---

## Step 0.0 — Project Initialization & Native Toolchains

**Goal:** Set up the Flutter workspace and the native C/C++ toolchains required for FFI compilation on target platforms.

### What is built in this step
- Initialize the Flutter project targeting macOS and Android.
- Set up the `ffi` package and configure CMake (Android) and CocoaPods/Xcode (macOS) to compile a dummy C++ library.
- Implement a basic "Hello World" FFI call from Dart to C++ to verify the toolchains are correctly linking on both platforms.

---

## Step 0.1 — Core Audio Engine Binding

**Goal:** Integrate a cross-platform C++ audio library (e.g., SoLoud, miniaudio, or similar) to handle the lowest-level buffer delivery to the OS audio APIs.

### What is built in this step
- Embed the chosen C++ audio library into the native build process.
- Establish the FFI bindings to initialize the audio engine, load an audio file from a path, and trigger play/pause.
- **Verification:** Dart code can successfully command the C++ engine to play a local MP3/WAV file on both macOS and Android without crashing.

---

## Step 0.2 — The Signal Chain Base

**Goal:** Replicate the foundational stages of the legacy app's signal chain in C++.

### What is built in this step
- **Normalize Gain Stage:** RMS-based loudness analysis and dynamic gain adjustment.
- **Crossfade & Input Mixer:** Support for decoding two audio streams simultaneously and blending their outputs based on a crossfade curve.
- Expose FFI functions to control target normalization levels and crossfade durations.

---

## Step 0.3 — The EQ & DSP Pipeline

**Goal:** Implement the 10-band equalizer and spatial effects in the native layer, ensuring sample-accurate processing.

### What is built in this step
- **10-Band EQ:** A chain of 10 biquad filters (32Hz–16kHz). The mathematical logic from the legacy app can be directly ported here.
- **Stereo Width / Mono:** Mid/Side matrix processing to widen or collapse the stereo image.
- **Compressor/Limiter:** A hard limiter at the end of the chain to prevent clipping when heavy EQ boosts are applied.
- Expose FFI functions to set individual band gains (±12dB), toggle mono, and adjust width.

---

## Step 0.4 — Dart FFI Bridge & Engine Controller

**Goal:** Create a robust, type-safe Dart wrapper around the raw FFI bindings.

### What is built in this step
- `AudioEngineController.dart`: A Dart class that abstracts the FFI calls, providing a clean async API for the rest of the Flutter app.
- Implement memory management: ensure any memory allocated in C++ for audio buffers is safely freed when the engine shuts down or changes tracks.

---

## Step 0.5 — Validation & Stress Test

**Goal:** Prove the engine works flawlessly before advancing to Phase 1.

### What is built in this step
- A temporary, bare-bones Flutter UI with:
  - A play/pause button.
  - 10 basic sliders for the EQ bands.
  - A stereo width slider.
- **Verification criteria:**
  - Audio plays cleanly on macOS and Android.
  - Adjusting EQ sliders produces immediate, artifact-free audio changes.
  - Backgrounding the app (on Android) does not immediately kill the audio (basic background capability verified, though full `audio_service` integration may happen in Phase 1).
  - No memory leaks during repeated track loading and unloading.

---

## Phase 0 — Completion Criteria

Phase 0 is complete when a developer can launch the app on both a Mac and an Android device, load a local audio file, and apply custom 10-band EQ and stereo width adjustments via a test UI, with the processing handled entirely by a unified C++ DSP layer.

**When these criteria are met, Phase 1 (UI & State Management) begins.**
