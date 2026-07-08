# APlayer — Cross-Platform Rebuild
## Project Plan & Technical Direction

*Prepared July 8, 2026*

---

## 1. Project Overview

A ground-up rebuild of the legacy APlayer as a fully cross-platform local music player. The legacy build (Vanilla JS + Electron + Capacitor) established a proven audio signal-chain design and platform-wrapper pattern, but its architecture does not scale cleanly beyond two platforms. This rebuild targets macOS and Android at launch, with Windows, Linux, iOS, and web explicitly planned as future targets — so the framework and architecture are chosen for that trajectory from day one.

The ambient soundscape mixer from the legacy app is intentionally excluded. This is a focused local/synced music player: playback, equalization, stereo control, auto volume leveling, playlists, shuffle, and optional Google Drive sync.

---

## 2. Platform & Framework Decision

- **Framework:** Flutter (Dart)
- **Launch platforms:** macOS, Android
- **Planned future platforms:** Windows, Linux, iOS, Web

Flutter was chosen over an updated Electron + Capacitor approach (the legacy pattern) because it offers a single first-party codebase across all six target platforms, rather than two separately maintained native shells. The Electron/Capacitor path would have required ongoing platform-shell maintenance that compounds with every new platform added; Flutter's cost is concentrated instead into one well-defined subproject (Section 3) rather than an open-ended maintenance tax.

### 2.1 Why not Electron + Capacitor again

- Two separate native shells to maintain indefinitely, each with its own packaging, signing, and store quirks.
- "Shared logic" only covers JS business logic — native plumbing (file access, background audio, notifications) must still be solved per-shell, as the legacy app's custom IPC bridge demonstrated.
- Every additional platform (Windows, Linux, iOS) means re-evaluating shell coverage rather than simply re-targeting a build.

### 2.2 Why Flutter

- One codebase, one engine, native compilation on macOS, Android, Windows, Linux, iOS, and Web.
- Team is already comfortable with Dart; no framework-fluency ramp-up cost.
- No legacy code reuse constraint — a clean rebuild is acceptable and preferred.
- Long-term maintenance burden is lower: platform SDK bumps and store compliance updates are the primary ongoing cost, not shell upkeep (see Section 8).

---

## 3. Audio Engine — The One Real Technical Risk

Flutter has no equivalent to the Web Audio API that powered the legacy signal chain. This is the single largest technical departure from the legacy build and is treated as its own subproject rather than an assumed "plug-and-play" package.

### 3.1 Playback & background audio

- **just_audio** — core playback engine: gapless playback, queues, multiple sources.
- **audio_service** — background playback, lock-screen controls, media session integration on both macOS and Android.
- **audio_session** — coexistence with system audio (calls, other apps).

### 3.2 Signal chain (EQ, stereo width, normalization, limiter)

Mainstream Flutter equalizer packages (e.g. `equalizer_flutter`) wrap the Android OS-level equalizer only and have no macOS/iOS equivalent. There is no first-party, cross-platform, sample-accurate DSP package that replicates what Web Audio API provided for free in the legacy build.

**Approach:** implement the signal chain as a custom DSP layer via Dart FFI, bound to a cross-platform native audio engine (e.g. SoLoud) rather than per-OS plugins. This keeps one DSP implementation shared across every platform, matching the original design philosophy of a single unified audio path.

Critically, the legacy app's signal chain design and biquad EQ logic remain directly reusable as a reference — only the host API changes, not the underlying algorithm:

- `Source → Normalize Gain → Crossfade Gain → Input Mixer`
- `Input Mixer → Compressor/Limiter → 10-Band EQ (Biquad chain) → Stereo Width (Mid/Side) → Master Gain → Output`

This subproject should be scoped, built, and validated early, before UI work depends on it, since it carries the most schedule risk.

---

## 4. Feature Scope

### 4.1 Carried over from legacy (reimplemented, not ported)

- 10-band equalizer, 32Hz–16kHz, ±12dB — same range and behavior as legacy, presets reorganized (see 4.3).
- Stereo width / mono configuration control.
- Auto volume adjust — RMS-based loudness normalization, same principle as legacy's normalization stage.
- Crossfade between tracks.
- Shuffle (Fisher-Yates) with state-snapshotting for unshuffle.
- Playlist creation, editing, and export.
- Local folder/file scanning, adapted per platform (native file access on macOS, storage-scoped picker on Android).

### 4.2 Explicitly excluded

- Ambient soundscape mixer and all associated presets/categories — not part of this build.

### 4.3 New in this build

- Reorganized, more diverse EQ presets — grouped by clear use-case categories (e.g. Bass Boost, Vocal/Podcast, Flat/Reference, Genre-based sets) rather than an unsorted list.
- Optional Google Drive sync (Section 5) — off by default, opt-in per user.

---

## 5. Google Drive Sync

**Status:** Opt-in only. App is fully functional offline/local-only by default.

Because sync is optional, there is no default impact on storage, permissions, or setup — users who never enable it experience a purely local player, consistent with the legacy app's model.

### 5.1 Core design decisions

| Decision point | Direction |
|---|---|
| Scope | Sync actual audio files (user's own files to their own Drive storage — no licensing concern, same principle as Dropbox-style personal backup). |
| Trigger | Wi-Fi only, to avoid mobile data usage; triggered on new file add and on reconnect to Wi-Fi. |
| Sync model | To be finalized: mirror (full local copy on every device) vs. stream-on-demand (Drive as source of truth, local cache only). Affects mobile storage footprint significantly and should be decided before implementation. |
| Storage disclosure | One-time notice to user estimating Drive storage usage before first enabling sync. |
| Conflict handling | Needed for playlists/metadata edited offline on two devices; last-write-wins is the simplest starting point, with a possible merge strategy for playlists specifically. |
| Auth | OAuth via Google Drive API; flow differs slightly between macOS (Electron-style browser auth is not applicable here — use Flutter-native OAuth flow) and Android. |

---

## 6. Architecture Notes

- State management: to be decided during implementation planning (e.g. Riverpod/Bloc) — not yet locked.
- DSP layer sits below the playback layer and is UI-agnostic, so the same engine serves macOS and Android identically, and future platforms without rework.
- Playlist data stored as JSON, consistent with the legacy format, to keep the door open for local import/export regardless of sync status.

---

## 7. Licensing

**Project license:** MIT License

MIT was selected as the default: permissive, broadly compatible with the Flutter/Dart package ecosystem (the vast majority of which is MIT/BSD-licensed), and does not create friction for future commercial distribution via the App Store or Play Store, or for accepting outside contributions later. This can be revisited if commercial or distribution plans change materially.

---

## 8. Long-Term Maintenance Expectations

The app is not expected to require continuous updates once core features are stable. However, "zero maintenance" is not realistic for any app integrating with an OS and an external API — this applies equally regardless of framework choice. Realistic, low-frequency maintenance triggers:

- Periodic OS-mandated SDK target bumps (Apple/Google require minimum target API/SDK levels to remain listed).
- Flutter SDK updates needed to stay compatible with new OS releases (permission model or audio session changes).
- Google Drive API / OAuth flow deprecations, relevant only to the opt-in sync feature.

To keep this burden as low as possible, the DSP/FFI layer in particular should avoid dependence on poorly-maintained or bleeding-edge packages, since it is the piece most exposed to long-term upstream change.

---

## 9. Open Items for Next Planning Pass

- Finalize Drive sync model: mirror vs. stream-on-demand.
- Choose state management approach (Riverpod, Bloc, or other).
- Scope and prototype the FFI/native audio DSP subproject in isolation before UI integration.
- Define final EQ preset categories and initial preset list.
- Define conflict-resolution behavior for playlist sync specifically.
