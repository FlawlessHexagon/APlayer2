import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
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
  
  final List<double> _eqGains = List.filled(10, 0.0);
  final List<String> _eqLabels = ['32', '64', '125', '250', '500', '1K', '2K', '4K', '8K', '16K'];
  
  double _stereoWidth = 1.0;
  bool _monoEnabled = false;

  bool _isStressTesting = false;
  Timer? _stressTimer;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _controller.init();
      
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

  void _play() {
    try {
      _controller.play();
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

  void _pause() {
    try {
      _controller.pause();
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
      
      await _controller.crossfadeToFile(file.path, const Duration(milliseconds: 2000));
      
      setState(() {
        _isPlaying = true;
      });
    } catch(e) {
      setState(() {
        _status = 'Crossfade error: $e';
      });
    }
  }

  void _toggleStressTest() {
    if (_isStressTesting) {
      _stressTimer?.cancel();
      setState(() {
        _isStressTesting = false;
        _status = 'Stress test stopped';
      });
    } else {
      setState(() {
        _isStressTesting = true;
        _status = 'Stress testing active!';
      });
      if (!_isPlaying) _play();
      
      int count = 0;
      final random = math.Random();
      _stressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
        count++;
        // Rapid track change every 1.5 seconds (stresses decoder load/unload & memory bounds)
        if (count % 10 == 0) {
          _nextTrack();
        }
        
        // Randomize all 10 EQ bands (stresses biquad recalculation & limiter)
        for (int i = 0; i < 10; i++) {
          double val = (random.nextDouble() * 24.0) - 12.0; // -12 to 12
          setState(() => _eqGains[i] = val);
          _controller.setEqBandGain(audio_dsp.EqBand.values[i], val);
        }
        
        // Rapid width & mono toggling
        double w = random.nextDouble() * 2.0;
        setState(() => _stereoWidth = w);
        _controller.setStereoWidth(w);
        
        if (count % 5 == 0) {
          bool m = random.nextBool();
          setState(() => _monoEnabled = m);
          _controller.setMono(m);
        }
      });
    }
  }

  @override
  void dispose() {
    _stressTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('APlayer2 DSP Test')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(_status, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton(
                    onPressed: (_isReady && !_isPlaying && !_isStressTesting) ? _play : null,
                    child: const Text('Play'),
                  ),
                  ElevatedButton(
                    onPressed: (_isReady && _isPlaying && !_isStressTesting) ? _pause : null,
                    child: const Text('Pause'),
                  ),
                  ElevatedButton(
                    onPressed: (_isReady && !_isStressTesting) ? _nextTrack : null,
                    child: const Text('Load / Next Track'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isStressTesting ? Colors.red : Colors.orange,
                    ),
                    onPressed: _isReady ? _toggleStressTest : null,
                    child: Text(_isStressTesting ? 'STOP STRESS TEST' : 'START STRESS TEST'),
                  ),
                ],
              ),
              const Divider(height: 30),
              const Text('10-Band EQ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(10, (index) {
                    return Column(
                      children: [
                        Text(_eqGains[index].toStringAsFixed(1)),
                        SizedBox(
                          height: 150,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: _eqGains[index],
                              min: -12.0,
                              max: 12.0,
                              onChanged: _isStressTesting ? null : (val) {
                                setState(() {
                                  _eqGains[index] = val;
                                });
                                _controller.setEqBandGain(audio_dsp.EqBand.values[index], val);
                              },
                            ),
                          ),
                        ),
                        Text(_eqLabels[index]),
                      ],
                    );
                  }),
                ),
              ),
              const Divider(height: 30),
              const Text('Spatial FX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  const Text('Width:'),
                  Expanded(
                    child: Slider(
                      value: _stereoWidth,
                      min: 0.0,
                      max: 2.0,
                      onChanged: _isStressTesting ? null : (val) {
                        setState(() => _stereoWidth = val);
                        _controller.setStereoWidth(val);
                      },
                    ),
                  ),
                  Text(_stereoWidth.toStringAsFixed(2)),
                ],
              ),
              SwitchListTile(
                title: const Text('Force Mono'),
                value: _monoEnabled,
                onChanged: _isStressTesting ? null : (val) {
                  setState(() => _monoEnabled = val);
                  _controller.setMono(val);
                },
              ),
              const Divider(height: 30),
              const Text('Normalization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SwitchListTile(
                title: const Text('Enable RMS Normalization'),
                value: _normEnabled,
                onChanged: _isStressTesting ? null : (val) {
                  setState(() => _normEnabled = val);
                  _controller.enableNormalization(val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
