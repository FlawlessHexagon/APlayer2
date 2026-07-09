import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_dsp/audio_dsp.dart';
import 'audio_provider.dart';

class EqPresets {
  static const Map<String, Map<EqBand, double>> presets = {
    'Reference (Flat)': {
      EqBand.hz32: 0.0, EqBand.hz64: 0.0, EqBand.hz125: 0.0, EqBand.hz250: 0.0, EqBand.hz500: 0.0,
      EqBand.hz1k: 0.0, EqBand.hz2k: 0.0, EqBand.hz4k: 0.0, EqBand.hz8k: 0.0, EqBand.hz16k: 0.0,
    },
    'Bass Boost': {
      EqBand.hz32: 6.0, EqBand.hz64: 5.0, EqBand.hz125: 4.0, EqBand.hz250: 2.0, EqBand.hz500: 0.0,
      EqBand.hz1k: 0.0, EqBand.hz2k: 0.0, EqBand.hz4k: 0.0, EqBand.hz8k: 0.0, EqBand.hz16k: 0.0,
    },
    'Treble Boost': {
      EqBand.hz32: 0.0, EqBand.hz64: 0.0, EqBand.hz125: 0.0, EqBand.hz250: 0.0, EqBand.hz500: 0.0,
      EqBand.hz1k: 0.0, EqBand.hz2k: 2.0, EqBand.hz4k: 4.0, EqBand.hz8k: 5.0, EqBand.hz16k: 6.0,
    },
    'Loudness': {
      EqBand.hz32: 6.0, EqBand.hz64: 4.0, EqBand.hz125: 0.0, EqBand.hz250: 0.0, EqBand.hz500: 0.0,
      EqBand.hz1k: 0.0, EqBand.hz2k: 0.0, EqBand.hz4k: 0.0, EqBand.hz8k: 4.0, EqBand.hz16k: 6.0,
    },
    'Electronic': {
      EqBand.hz32: 5.0, EqBand.hz64: 4.0, EqBand.hz125: 1.0, EqBand.hz250: 0.0, EqBand.hz500: -2.0,
      EqBand.hz1k: 0.0, EqBand.hz2k: 1.0, EqBand.hz4k: 3.0, EqBand.hz8k: 4.0, EqBand.hz16k: 5.0,
    },
    'Acoustic': {
      EqBand.hz32: 2.0, EqBand.hz64: 2.0, EqBand.hz125: 1.0, EqBand.hz250: 0.0, EqBand.hz500: 1.0,
      EqBand.hz1k: 1.0, EqBand.hz2k: 2.0, EqBand.hz4k: 2.0, EqBand.hz8k: 2.0, EqBand.hz16k: 1.0,
    },
    'Classical': {
      EqBand.hz32: 3.0, EqBand.hz64: 3.0, EqBand.hz125: 2.0, EqBand.hz250: 1.0, EqBand.hz500: -1.0,
      EqBand.hz1k: -1.0, EqBand.hz2k: 0.0, EqBand.hz4k: 2.0, EqBand.hz8k: 3.0, EqBand.hz16k: 3.0,
    },
    'Rock': {
      EqBand.hz32: 5.0, EqBand.hz64: 4.0, EqBand.hz125: 2.0, EqBand.hz250: -1.0, EqBand.hz500: -2.0,
      EqBand.hz1k: -1.0, EqBand.hz2k: 1.0, EqBand.hz4k: 3.0, EqBand.hz8k: 4.0, EqBand.hz16k: 4.0,
    },
    'Vocal / Podcast': {
      EqBand.hz32: -2.0, EqBand.hz64: -2.0, EqBand.hz125: -1.0, EqBand.hz250: 2.0, EqBand.hz500: 4.0,
      EqBand.hz1k: 4.0, EqBand.hz2k: 3.0, EqBand.hz4k: 1.0, EqBand.hz8k: 0.0, EqBand.hz16k: -1.0,
    },
  };
}

class DspState {
  final Map<EqBand, double> eqGains;
  final double stereoWidth;
  final bool isMono;
  final String activePreset;

  DspState({
    required this.eqGains,
    this.stereoWidth = 1.0,
    this.isMono = false,
    this.activePreset = 'Reference (Flat)',
  });

  DspState copyWith({
    Map<EqBand, double>? eqGains,
    double? stereoWidth,
    bool? isMono,
    String? activePreset,
  }) {
    return DspState(
      eqGains: eqGains ?? this.eqGains,
      stereoWidth: stereoWidth ?? this.stereoWidth,
      isMono: isMono ?? this.isMono,
      activePreset: activePreset ?? this.activePreset,
    );
  }
}

class DspStateNotifier extends Notifier<DspState> {
  @override
  DspState build() {
    return DspState(
      eqGains: Map.from(EqPresets.presets['Reference (Flat)']!),
    );
  }

  AudioEngineController get _engine => ref.read(audioEngineProvider);

  void setEqBandGain(EqBand band, double gainDb) {
    _engine.setEqBandGain(band, gainDb);
    final newGains = Map<EqBand, double>.from(state.eqGains);
    newGains[band] = gainDb;
    state = state.copyWith(eqGains: newGains, activePreset: 'Custom');
  }

  void setStereoWidth(double width) {
    _engine.setStereoWidth(width);
    state = state.copyWith(stereoWidth: width);
  }

  void setMono(bool enable) {
    _engine.setMono(enable);
    state = state.copyWith(isMono: enable);
  }

  void applyPreset(String presetName) {
    final presetGains = EqPresets.presets[presetName];
    if (presetGains == null) return;

    presetGains.forEach((band, gain) {
      _engine.setEqBandGain(band, gain);
    });
    
    state = state.copyWith(
      eqGains: Map.from(presetGains),
      activePreset: presetName,
    );
  }
}

final dspStateProvider = NotifierProvider<DspStateNotifier, DspState>(() {
  return DspStateNotifier();
});
