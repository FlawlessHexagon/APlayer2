# Development Phase 2 — Library & Sync
## Detailed Implementation Plan

*Prepared July 9, 2026*

*Phase 2 shifts focus from audio playback to data management. It establishes the local database for track metadata, implements device storage scanning, builds the playback queue logic, and introduces the optional Google Drive sync functionality.*

---

## Guiding Principles for Phase 2

1. **Local-First Architecture:** The application must function flawlessly without an internet connection. All Drive-synced data must be mirrored (downloaded) to local storage. Streaming directly from Drive is explicitly prohibited to ensure stability with the custom native DSP engine.
2. **Deterministic Shuffle:** The shuffle algorithm must be a true random sort that guarantees every track in a playlist is played exactly once before any track is repeated.
3. **Graceful Sync:** Google Drive synchronization must occur in the background and gracefully handle conflicts using a "Last-Write-Wins" policy based on timestamp.

---

## Step 2.0 — Local Data Foundation

**Goal:** Establish the local database and core data models.

### What is built in this step
- Integrate a high-performance local database (e.g., `isar` or `sqflite`).
- Define the data models: `Track` (metadata, file path, duration, sync status), `Playlist`, and `QueueState`.
- Create Riverpod providers/repositories for database CRUD operations.

---

## Step 2.1 — Local File Scanner

**Goal:** Allow users to populate their library by scanning local device storage.

### What is built in this step
- Implement a recursive directory scanner for macOS and Android.
- Integrate an ID3 metadata extraction package (or utilize FFI to a native library).
- Persist scanned tracks to the database and map album art URIs.
- Provide a progress stream to the UI during deep scans.

---

## Step 2.2 — Queue & Shuffle Logic

**Goal:** Implement robust playlist queuing and playback ordering.

### What is built in this step
- Build a `QueueManager` that interfaces with the Phase 1 `playbackStateProvider`.
- Implement standard playback modes: Linear, Repeat Track, Repeat All.
- Implement True Shuffle: Generate a randomized index array of the current playlist to ensure non-repeating playback.

---

## Step 2.3 — Library UI

**Goal:** Build the user interfaces for managing the music collection.

### What is built in this step
- **Library Screen:** A list/grid view of all tracks, sorted by Artist/Album/Title.
- **Playlist Manager:** Screens to create, edit, and reorder playlists.
- Ensure all screens adhere to the `doc_ui_design_system.md` specifications (JetBrains Mono, Deep Purple theme).

---

## Step 2.4 — Google Drive Sync Integration

**Goal:** Enable optional cloud backup and cross-device syncing.

### What is built in this step
- Implement the Google OAuth flow for both macOS and Android.
- Build the Sync Engine to upload local playlists (as JSON) and mirror remote audio files to local app storage.
- Implement the Last-Write-Wins conflict resolution strategy for playlist edits.

---

## Phase 2 — Completion Criteria

Phase 2 is complete when a user can point the app at a local folder full of MP3s, see their library populate with metadata, create a playlist, shuffle it perfectly, and optionally back that playlist up to Google Drive.
