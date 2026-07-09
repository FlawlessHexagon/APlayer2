import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_dsp/audio_dsp.dart';
import '../providers/dsp_provider.dart';
import '../theme/app_theme.dart';

class DspControlScreen extends ConsumerWidget {
  const DspControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dspState = ref.watch(dspStateProvider);
    final dspNotifier = ref.read(dspStateProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DSP Engine'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Preset Dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  const Text('Preset: ', style: TextStyle(color: AppColors.offWhite, fontSize: 16)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.purpleAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: AppColors.purpleAccent,
                          value: dspState.activePreset == 'Custom' ? null : dspState.activePreset,
                          hint: Text(dspState.activePreset, style: const TextStyle(color: AppColors.beige)),
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.beige),
                          isExpanded: true,
                          items: EqPresets.presets.keys.map((String preset) {
                            return DropdownMenuItem<String>(
                              value: preset,
                              child: Text(preset, style: const TextStyle(color: AppColors.offWhite)),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              dspNotifier.applyPreset(newValue);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // 10 Band EQ Sliders
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: EqBand.values.map((band) {
                    final label = _getBandLabel(band);
                    final gain = dspState.eqGains[band] ?? 0.0;
                    return Expanded(
                      child: Column(
                        children: [
                          Text('${gain > 0 ? '+' : ''}${gain.toStringAsFixed(1)}', style: const TextStyle(color: AppColors.midGrey, fontSize: 10)),
                          const SizedBox(height: 8),
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.beige,
                                  inactiveTrackColor: AppColors.midGrey.withOpacity(0.3),
                                  thumbColor: AppColors.beige,
                                  overlayColor: AppColors.beige.withOpacity(0.2),
                                  trackHeight: 4.0,
                                ),
                                child: Slider(
                                  value: gain,
                                  min: -12.0,
                                  max: 12.0,
                                  onChanged: (val) {
                                    dspNotifier.setEqBandGain(band, val);
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(label, style: const TextStyle(color: AppColors.offWhite, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            const Divider(color: AppColors.midGrey, height: 1),
            const SizedBox(height: 20),
            
            // Spatial Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spatial Audio', style: TextStyle(color: AppColors.offWhite, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.compare_arrows, color: AppColors.midGrey),
                      const SizedBox(width: 16),
                      const Text('Width', style: TextStyle(color: AppColors.midGrey)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.beige,
                            inactiveTrackColor: AppColors.midGrey.withOpacity(0.3),
                            thumbColor: AppColors.beige,
                          ),
                          child: Slider(
                            value: dspState.stereoWidth,
                            min: 0.0,
                            max: 3.0,
                            onChanged: (val) {
                              dspNotifier.setStereoWidth(val);
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(dspState.stereoWidth.toStringAsFixed(2), style: const TextStyle(color: AppColors.beige)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.speaker_group, color: AppColors.midGrey),
                          SizedBox(width: 16),
                          Text('Mono Downmix', style: TextStyle(color: AppColors.midGrey)),
                        ],
                      ),
                      Switch(
                        value: dspState.isMono,
                        activeColor: AppColors.beige,
                        activeTrackColor: AppColors.beige.withOpacity(0.5),
                        inactiveThumbColor: AppColors.midGrey,
                        inactiveTrackColor: AppColors.purpleAccent,
                        onChanged: (val) {
                          dspNotifier.setMono(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getBandLabel(EqBand band) {
    switch (band) {
      case EqBand.hz32: return '32';
      case EqBand.hz64: return '64';
      case EqBand.hz125: return '125';
      case EqBand.hz250: return '250';
      case EqBand.hz500: return '500';
      case EqBand.hz1k: return '1K';
      case EqBand.hz2k: return '2K';
      case EqBand.hz4k: return '4K';
      case EqBand.hz8k: return '8K';
      case EqBand.hz16k: return '16K';
    }
  }
}
