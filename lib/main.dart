import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:audio_dsp/audio_dsp.dart' as audio_dsp;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _controller = audio_dsp.AudioEngineController();
  String _status = 'Initializing...';
  bool _isPlaying = false;
  bool _isReady = false;
  
  bool _normEnabled = false;
  double _targetDb = -14.0;
  bool _isSample1 = true;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _controller.init();
      
      // Copy assets to temp file
      await _copyAsset('sample.wav');
      await _copyAsset('sample2.wav');
      
      final file1 = File('${Directory.systemTemp.path}/sample.wav');
      await _controller.load(file1.path);
      
      if (mounted) {
        setState(() {
          _status = 'Ready to play';
          _isReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
        });
      }
    }
  }

  Future<void> _copyAsset(String name) async {
    final byteData = await rootBundle.load('assets/$name');
    final file = File('${Directory.systemTemp.path}/$name');
    await file.writeAsBytes(byteData.buffer.asUint8List());
  }

  Future<void> _play() async {
    try {
      await _controller.play();
      setState(() {
        _isPlaying = true;
        _status = 'Playing';
      });
    } catch (e) {
      setState(() {
        _status = 'Play error: $e';
      });
    }
  }

  Future<void> _pause() async {
    try {
      await _controller.pause();
      setState(() {
        _isPlaying = false;
        _status = 'Paused';
      });
    } catch (e) {
      setState(() {
        _status = 'Pause error: $e';
      });
    }
  }
  
  Future<void> _nextTrack() async {
    try {
      _isSample1 = !_isSample1;
      String nextFile = _isSample1 ? 'sample.wav' : 'sample2.wav';
      final file = File('${Directory.systemTemp.path}/$nextFile');
      
      setState(() {
        _status = 'Crossfading to $nextFile...';
      });
      
      await _controller.crossfadeToFile(file.path, 2000);
      
      setState(() {
        _isPlaying = true;
      });
    } catch(e) {
      setState(() {
        _status = 'Crossfade error: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('APlayer2 DSP Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: (_isReady && !_isPlaying) ? _play : null,
                  child: const Text('Play'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: (_isReady && _isPlaying) ? _pause : null,
                  child: const Text('Pause'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isReady ? _nextTrack : null,
                  child: const Text('Next Track (Crossfade)'),
                ),
              ],
            ),
            const Divider(height: 40),
            SwitchListTile(
              title: const Text('Enable RMS Normalization'),
              value: _normEnabled,
              onChanged: (val) {
                setState(() => _normEnabled = val);
                _controller.enableNormalization(val);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Text('Target dB:'),
                  Expanded(
                    child: Slider(
                      value: _targetDb,
                      min: -30.0,
                      max: 0.0,
                      onChanged: (val) {
                        setState(() => _targetDb = val);
                        _controller.setNormalizationTarget(val);
                      },
                    ),
                  ),
                  Text('${_targetDb.toStringAsFixed(1)} dB'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
