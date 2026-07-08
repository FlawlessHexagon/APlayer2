import 'dart:ffi';
import 'dart:io';

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

typedef _test_ffi_connection_func = Int32 Function();
typedef _TestFfiConnection = int Function();

final _TestFfiConnection _testFfiConnection = _dylib
    .lookup<NativeFunction<_test_ffi_connection_func>>('test_ffi_connection')
    .asFunction();

int testFfiConnection() => _testFfiConnection();
