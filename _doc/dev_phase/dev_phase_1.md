# Development Phase 1 — UI & State Management
## Detailed Implementation Plan

*Prepared July 9, 2026*

*Phase 1 connects the isolated native DSP engine from Phase 0 to a robust Flutter architecture. It establishes Riverpod for state management, builds the core playback UI, and integrates background audio services. File scanning and playlists are explicitly deferred to Phase 2.*

---

## Guiding Principles for Phase 1

1. **Strict Separation of State:** UI components must never communicate directly with the `AudioEngineController`. All playback control, DSP adjustments, and state polling must flow through Riverpod state providers.
2. **Reactive UI:** The UI must be fully reactive to audio state changes (position, duration, play state). Hardcoded state logic in UI files is prohibited.
3. **OS Integration First:** Background audio (`audio_service`) is not an afterthought; it must be wired up alongside the internal state to guarantee lock-screen controls remain perfectly synced.

---

## Step 1.0 — Architecture & State Foundation

**Goal:** Establish the app architecture and state management framework.

### What is built in this step
- Integrate `flutter_riverpod` as the single source of truth for app state.
- Set up a robust routing layer (e.g., `go_router`) to handle navigation between the Library (future) and the Now Playing screens.
- Establish the design system and theme engine: implement the strict visual identity defined in `ui_design_system.md` (JetBrains Mono and the Deep Purple/Beige palette).

---

## Step 1.1 — Audio State Integration

**Goal:** Wrap the Phase 0 native engine in a reactive state layer.

### What is built in this step
- **Global Providers:** Create Riverpod providers that house the `AudioEngineController`.
- **State Emitting:** Implement a state stream that broadcasts the current playback state (playing/paused), current track position, and track duration to the UI at 60fps (or whatever refresh rate is required for smooth seek bars).

---

## Step 1.2 — Background Audio Service

**Goal:** Ensure playback persists in the background and responds to OS media controls.

### What is built in this step
- Integrate `audio_service` to expose the Flutter audio session to Android (MediaSession) and macOS (Now Playing info center).
- Map OS media commands (Play, Pause, Next, Prev, Seek) securely to the Riverpod audio providers.
- Broadcast track metadata (Title, Artist, Album Art) to the OS.

---

## Step 1.3 — Core Playback UI

**Goal:** Build the primary user interface for music playback.

### What is built in this step
- **Now Playing Screen:** A premium, fully responsive screen displaying album art, track info, and playback controls.
- **Seek Bar:** A highly responsive slider connected to the position state, handling drag-to-seek without stuttering.
- **Micro-Animations:** Implement smooth, aesthetic transitions for play/pause toggles and track changes to fulfill the "premium dynamic design" requirement.

---

## Step 1.4 — DSP Control UI

**Goal:** Build the user-facing controls for the audio engine's DSP features.

### What is built in this step
- **Equalizer Screen:** A polished interface for the 10-band EQ.
- **Spatial Controls:** Intuitive sliders for stereo width and a toggle for mono.
- **Preset System:** Hardcoded JSON categories (e.g., Bass Boost, Flat/Reference, Vocal/Podcast) that instantly apply EQ configurations when selected by the user.

---

## Phase 1 — Completion Criteria

Phase 1 is complete when a user can load a track (via temporary debug means if necessary), view an animated Now Playing screen, interact with a perfectly synced seek bar, adjust the EQ via a polished UI, and put the app in the background while fully controlling playback from the OS media session.

**When these criteria are met, Phase 2 (Library & Sync) begins.**
