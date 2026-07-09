import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

const String _libName = 'audio_dsp';

final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

// --- Raw FFI Signatures ---

typedef _init_audio_engine_func = Int32 Function();
typedef _InitAudioEngine = int Function();

typedef _load_audio_file_func = Int32 Function(Pointer<Utf8> path);
typedef _LoadAudioFile = int Function(Pointer<Utf8> path);

typedef _play_audio_func = Int32 Function();
typedef _PlayAudio = int Function();

typedef _pause_audio_func = Int32 Function();
typedef _PauseAudio = int Function();

typedef _shutdown_audio_engine_func = Int32 Function();
typedef _ShutdownAudioEngine = int Function();

typedef _set_normalization_target_func = Void Function(Float target);
typedef _SetNormalizationTarget = void Function(double target);

typedef _enable_normalization_func = Void Function(Bool enable);
typedef _EnableNormalization = void Function(bool enable);

typedef _crossfade_to_file_func = Int32 Function(Pointer<Utf8> path, Int32 durationMs);
typedef _CrossfadeToFile = int Function(Pointer<Utf8> path, int durationMs);

typedef _set_eq_band_gain_func = Void Function(Int32 bandIndex, Float gainDb);
typedef _SetEqBandGain = void Function(int bandIndex, double gainDb);

typedef _set_stereo_width_func = Void Function(Float width);
typedef _SetStereoWidth = void Function(double width);

typedef _set_mono_func = Void Function(Bool enable);
typedef _SetMono = void Function(bool enable);

// --- Raw Function Pointers ---

final _InitAudioEngine _initAudioEngine = _dylib.lookup<NativeFunction<_init_audio_engine_func>>('init_audio_engine').asFunction();
final _LoadAudioFile _loadAudioFile = _dylib.lookup<NativeFunction<_load_audio_file_func>>('load_audio_file').asFunction();
final _PlayAudio _playAudio = _dylib.lookup<NativeFunction<_play_audio_func>>('play_audio').asFunction();
final _PauseAudio _pauseAudio = _dylib.lookup<NativeFunction<_pause_audio_func>>('pause_audio').asFunction();
final _ShutdownAudioEngine _shutdownAudioEngine = _dylib.lookup<NativeFunction<_shutdown_audio_engine_func>>('shutdown_audio_engine').asFunction();
final _SetNormalizationTarget _setNormalizationTarget = _dylib.lookup<NativeFunction<_set_normalization_target_func>>('set_normalization_target').asFunction();
final _EnableNormalization _enableNormalization = _dylib.lookup<NativeFunction<_enable_normalization_func>>('enable_normalization').asFunction();
final _CrossfadeToFile _crossfadeToFile = _dylib.lookup<NativeFunction<_crossfade_to_file_func>>('crossfade_to_file').asFunction();
final _SetEqBandGain _setEqBandGain = _dylib.lookup<NativeFunction<_set_eq_band_gain_func>>('set_eq_band_gain').asFunction();
final _SetStereoWidth _setStereoWidth = _dylib.lookup<NativeFunction<_set_stereo_width_func>>('set_stereo_width').asFunction();
final _SetMono _setMono = _dylib.lookup<NativeFunction<_set_mono_func>>('set_mono').asFunction();

typedef _get_duration_func = Float Function();
typedef _GetDuration = double Function();
final _GetDuration _getDuration = _dylib.lookup<NativeFunction<_get_duration_func>>('get_duration').asFunction();

typedef _get_position_func = Float Function();
typedef _GetPosition = double Function();
final _GetPosition _getPosition = _dylib.lookup<NativeFunction<_get_position_func>>('get_position').asFunction();

typedef _seek_to_position_func = Int32 Function(Float positionSeconds);
typedef _SeekToPosition = int Function(double positionSeconds);
final _SeekToPosition _seekToPosition = _dylib.lookup<NativeFunction<_seek_to_position_func>>('seek_to_position').asFunction();

// --- Strong Types ---

enum EqBand {
  hz32,
  hz64,
  hz125,
  hz250,
  hz500,
  hz1k,
  hz2k,
  hz4k,
  hz8k,
  hz16k
}

class AudioEngineException implements Exception {
  final String message;
  final int? errorCode;
  AudioEngineException(this.message, [this.errorCode]);

  @override
  String toString() => 'AudioEngineException: $message${errorCode != null ? ' (Code: $errorCode)' : ''}';
}

// --- Object-Oriented Controller ---

class AudioEngineController {
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initializes the native C++ audio engine.
  Future<void> init() async {
    if (_isInitialized) return;
    final res = _initAudioEngine();
    if (res != 0) {
      throw AudioEngineException('Failed to initialize audio engine', res);
    }
    _isInitialized = true;
  }

  /// Loads an audio file into the native engine for playback.
  Future<void> load(String path) async {
    _ensureInitialized();
    final pointer = path.toNativeUtf8();
    try {
      final res = _loadAudioFile(pointer);
      if (res != 0) {
        throw AudioEngineException('Failed to load audio file at path: $path', res);
      }
    } finally {
      malloc.free(pointer);
    }
  }

  /// Starts or resumes playback.
  void play() {
    _ensureInitialized();
    final res = _playAudio();
    if (res != 0) throw AudioEngineException('Failed to play audio', res);
  }

  /// Pauses playback.
  void pause() {
    _ensureInitialized();
    final res = _pauseAudio();
    if (res != 0) throw AudioEngineException('Failed to pause audio', res);
  }

  /// Returns the current track duration.
  Duration get duration {
    if (!_isInitialized) return Duration.zero;
    return Duration(milliseconds: (_getDuration() * 1000).toInt());
  }

  /// Returns the current playback position.
  Duration get position {
    if (!_isInitialized) return Duration.zero;
    return Duration(milliseconds: (_getPosition() * 1000).toInt());
  }

  /// Seeks to a specific position in the track.
  void seek(Duration pos) {
    _ensureInitialized();
    final res = _seekToPosition(pos.inMilliseconds / 1000.0);
    if (res != 0) throw AudioEngineException('Failed to seek', res);
  }

  /// Crossfades from the current track to a new file over [duration].
  Future<void> crossfadeToFile(String path, Duration duration) async {
    _ensureInitialized();
    final pointer = path.toNativeUtf8();
    try {
      final res = _crossfadeToFile(pointer, duration.inMilliseconds);
      if (res != 0) {
        throw AudioEngineException('Failed to crossfade to file at path: $path', res);
      }
    } finally {
      malloc.free(pointer);
    }
  }

  /// Sets the RMS normalization target in decibels (e.g., -14.0 dB).
  void setNormalizationTarget(double targetDb) {
    _ensureInitialized();
    _setNormalizationTarget(targetDb);
  }

  /// Toggles the RMS normalization stage.
  void enableNormalization(bool enable) {
    _ensureInitialized();
    _enableNormalization(enable);
  }

  /// Sets the gain of a specific [EqBand] between -12.0 and +12.0 dB.
  void setEqBandGain(EqBand band, double gainDb) {
    _ensureInitialized();
    // Clamp to prevent extreme values reaching C++
    final clampedGain = gainDb.clamp(-12.0, 12.0);
    _setEqBandGain(band.index, clampedGain);
  }

  /// Sets the stereo width factor. 1.0 is normal, 0.0 is mono, >1.0 is wide.
  void setStereoWidth(double width) {
    _ensureInitialized();
    final clampedWidth = width.clamp(0.0, 3.0);
    _setStereoWidth(clampedWidth);
  }

  /// Forces the audio output into strict mono.
  void setMono(bool enable) {
    _ensureInitialized();
    _setMono(enable);
  }

  /// Safely shuts down the audio engine and releases native resources.
  void dispose() {
    if (!_isInitialized) return;
    final res = _shutdownAudioEngine();
    if (res != 0) {
      throw AudioEngineException('Failed to cleanly shutdown audio engine', res);
    }
    _isInitialized = false;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw AudioEngineException('Audio engine is not initialized. Call init() first.');
    }
  }
}
