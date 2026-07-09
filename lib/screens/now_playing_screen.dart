import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/audio_provider.dart';
import '../theme/app_theme.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _playPauseAnimController;
  double? _dragValue;

  @override
  void initState() {
    super.initState();
    _playPauseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _playPauseAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadTestTrack() async {
    final byteData = await rootBundle.load('assets/sample.wav');
    final file = File('${Directory.systemTemp.path}/sample.wav');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    ref.read(playbackStateProvider.notifier).loadTrack(file.path);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackStateProvider);
    final positionAsync = ref.watch(playbackPositionProvider);

    if (state.status == PlaybackStatus.playing && _playPauseAnimController.status != AnimationStatus.forward && _playPauseAnimController.status != AnimationStatus.completed) {
      _playPauseAnimController.forward();
    } else if (state.status == PlaybackStatus.paused && _playPauseAnimController.status != AnimationStatus.reverse && _playPauseAnimController.status != AnimationStatus.dismissed) {
      _playPauseAnimController.reverse();
    }

    final duration = state.duration;
    final position = positionAsync.value ?? Duration.zero;

    final sliderValue = _dragValue ?? position.inMilliseconds.toDouble();
    final maxSliderValue = duration.inMilliseconds.toDouble();

    final safeSliderValue = sliderValue.clamp(0.0, maxSliderValue > 0 ? maxSliderValue : 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        actions: [
           IconButton(
             icon: const Icon(Icons.music_note),
             onPressed: _loadTestTrack,
             tooltip: 'Load Test Track',
           )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return _buildLandscapeLayout(safeSliderValue, maxSliderValue, duration, state);
          } else {
            return _buildPortraitLayout(safeSliderValue, maxSliderValue, duration, state);
          }
        },
      ),
    );
  }

  Widget _buildPortraitLayout(double sliderValue, double maxSliderValue, Duration duration, AppPlaybackState state) {
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Center(
            child: _buildAlbumArt(),
          ),
        ),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTrackInfo(),
                const SizedBox(height: 20),
                _buildSeekBar(sliderValue, maxSliderValue, duration),
                const SizedBox(height: 20),
                _buildPlaybackControls(state),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(double sliderValue, double maxSliderValue, Duration duration, AppPlaybackState state) {
    return Row(
      children: [
        Expanded(
          child: Center(
            child: _buildAlbumArt(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTrackInfo(),
                const SizedBox(height: 30),
                _buildSeekBar(sliderValue, maxSliderValue, duration),
                const SizedBox(height: 30),
                _buildPlaybackControls(state),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumArt() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        color: AppColors.purpleAccent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.album, size: 100, color: AppColors.midGrey),
    );
  }

  Widget _buildTrackInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        Text(
          'Validation Track',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.offWhite),
        ),
        SizedBox(height: 8),
        Text(
          'APlayer Engine',
          style: TextStyle(fontSize: 16, color: AppColors.midGrey),
        ),
      ],
    );
  }

  Widget _buildSeekBar(double sliderValue, double maxSliderValue, Duration duration) {
    final currentPosDur = Duration(milliseconds: sliderValue.toInt());
    
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.beige,
            inactiveTrackColor: AppColors.midGrey.withOpacity(0.3),
            thumbColor: AppColors.beige,
            overlayColor: AppColors.beige.withOpacity(0.2),
            trackHeight: 4.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
          ),
          child: Slider(
            value: sliderValue,
            max: maxSliderValue > 0 ? maxSliderValue : 1.0,
            onChanged: (val) {
              setState(() {
                _dragValue = val;
              });
            },
            onChangeEnd: (val) {
              ref.read(playbackStateProvider.notifier).seek(Duration(milliseconds: val.toInt()));
              setState(() {
                _dragValue = null;
              });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(currentPosDur), style: Theme.of(context).textTheme.bodySmall),
            Text(_formatDuration(duration), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaybackControls(AppPlaybackState state) {
    final isLoading = state.status == PlaybackStatus.loading;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: 36,
          color: AppColors.offWhite,
          onPressed: () {},
        ),
        const SizedBox(width: 20),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.beige,
          ),
          child: isLoading 
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: AppColors.nearBlack, strokeWidth: 3),
              )
            : IconButton(
                icon: AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: _playPauseAnimController,
                ),
                iconSize: 36,
                color: AppColors.nearBlack,
                onPressed: () {
                  final notifier = ref.read(playbackStateProvider.notifier);
                  if (state.status == PlaybackStatus.playing) {
                    notifier.pause();
                  } else {
                    notifier.play();
                  }
                },
              ),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: 36,
          color: AppColors.offWhite,
          onPressed: () {},
        ),
      ],
    );
  }
}
