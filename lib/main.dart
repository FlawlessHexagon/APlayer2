import 'package:flutter/material.dart';
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
  String _result = 'Not tested yet';

  void _testFfi() {
    try {
      final res = audio_dsp.testFfiConnection();
      setState(() {
        _result = 'Result: $res';
      });
      print('FFI Result: $res');
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
      print('FFI Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('APlayer2 FFI Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_result),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _testFfi,
              child: const Text('Test FFI'),
            ),
          ],
        ),
      ),
    );
  }
}
