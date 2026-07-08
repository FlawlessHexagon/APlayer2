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

final _InitAudioEngine _initAudioEngine = _dylib
    .lookup<NativeFunction<_init_audio_engine_func>>('init_audio_engine')
    .asFunction();

final _LoadAudioFile _loadAudioFile = _dylib
    .lookup<NativeFunction<_load_audio_file_func>>('load_audio_file')
    .asFunction();

final _PlayAudio _playAudio = _dylib
    .lookup<NativeFunction<_play_audio_func>>('play_audio')
    .asFunction();

final _PauseAudio _pauseAudio = _dylib
    .lookup<NativeFunction<_pause_audio_func>>('pause_audio')
    .asFunction();

final _ShutdownAudioEngine _shutdownAudioEngine = _dylib
    .lookup<NativeFunction<_shutdown_audio_engine_func>>('shutdown_audio_engine')
    .asFunction();

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
}
