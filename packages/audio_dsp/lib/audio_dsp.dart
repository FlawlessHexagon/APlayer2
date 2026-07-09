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

final _InitAudioEngine _initAudioEngine = _dylib.lookup<NativeFunction<_init_audio_engine_func>>('init_audio_engine').asFunction();
final _LoadAudioFile _loadAudioFile = _dylib.lookup<NativeFunction<_load_audio_file_func>>('load_audio_file').asFunction();
final _PlayAudio _playAudio = _dylib.lookup<NativeFunction<_play_audio_func>>('play_audio').asFunction();
final _PauseAudio _pauseAudio = _dylib.lookup<NativeFunction<_pause_audio_func>>('pause_audio').asFunction();
final _ShutdownAudioEngine _shutdownAudioEngine = _dylib.lookup<NativeFunction<_shutdown_audio_engine_func>>('shutdown_audio_engine').asFunction();
final _SetNormalizationTarget _setNormalizationTarget = _dylib.lookup<NativeFunction<_set_normalization_target_func>>('set_normalization_target').asFunction();
final _EnableNormalization _enableNormalization = _dylib.lookup<NativeFunction<_enable_normalization_func>>('enable_normalization').asFunction();
final _CrossfadeToFile _crossfadeToFile = _dylib.lookup<NativeFunction<_crossfade_to_file_func>>('crossfade_to_file').asFunction();

class AudioEngineController {
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    final res = _initAudioEngine();
    if (res != 0) throw Exception('Failed to initialize audio engine. Error code: $res');
    _isInitialized = true;
  }

  Future<void> load(String path) async {
    final pointer = path.toNativeUtf8();
    try {
      final res = _loadAudioFile(pointer);
      if (res != 0) throw Exception('Failed to load audio file. Error code: $res');
    } finally {
      malloc.free(pointer);
    }
  }

  Future<void> play() async {
    final res = _playAudio();
    if (res != 0) throw Exception('Failed to play audio. Error code: $res');
  }

  Future<void> pause() async {
    final res = _pauseAudio();
    if (res != 0) throw Exception('Failed to pause audio. Error code: $res');
  }

  Future<void> shutdown() async {
    final res = _shutdownAudioEngine();
    if (res != 0) throw Exception('Failed to shutdown audio engine. Error code: $res');
    _isInitialized = false;
  }

  void setNormalizationTarget(double targetDb) {
    _setNormalizationTarget(targetDb);
  }

  void enableNormalization(bool enable) {
    _enableNormalization(enable);
  }

  Future<void> crossfadeToFile(String path, int durationMs) async {
    final pointer = path.toNativeUtf8();
    try {
      final res = _crossfadeToFile(pointer, durationMs);
      if (res != 0) throw Exception('Failed to crossfade to file. Error code: $res');
    } finally {
      malloc.free(pointer);
    }
  }

  void setEqBandGain(int bandIndex, double gainDb) {
    _setEqBandGain(bandIndex, gainDb);
  }

  void setStereoWidth(double width) {
    _setStereoWidth(width);
  }

  void setMono(bool enable) {
    _setMono(enable);
  }
}

typedef _set_eq_band_gain_func = Void Function(Int32 bandIndex, Float gainDb);
typedef _SetEqBandGain = void Function(int bandIndex, double gainDb);

typedef _set_stereo_width_func = Void Function(Float width);
typedef _SetStereoWidth = void Function(double width);

typedef _set_mono_func = Void Function(Bool enable);
typedef _SetMono = void Function(bool enable);

final _SetEqBandGain _setEqBandGain = _dylib.lookup<NativeFunction<_set_eq_band_gain_func>>('set_eq_band_gain').asFunction();
final _SetStereoWidth _setStereoWidth = _dylib.lookup<NativeFunction<_set_stereo_width_func>>('set_stereo_width').asFunction();
final _SetMono _setMono = _dylib.lookup<NativeFunction<_set_mono_func>>('set_mono').asFunction();

