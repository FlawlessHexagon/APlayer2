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

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _controller.init();
      
      // Copy asset to temp file so C++ can read it
      final byteData = await rootBundle.load('assets/sample.wav');
      final file = File('${Directory.systemTemp.path}/sample.wav');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      await _controller.load(file.path);
      
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
  
  @override
  void dispose() {
    _controller.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('APlayer2 Audio Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: (_isReady && !_isPlaying) ? _play : null,
                  child: const Text('Play'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: (_isReady && _isPlaying) ? _pause : null,
                  child: const Text('Pause'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
