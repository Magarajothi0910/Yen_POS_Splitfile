// audio_provider.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'audio_provider.dart';
import 'wave_screen.dart';

class AudioPlayerWidget extends StatelessWidget {
  final String filePath;
  // final String? audioPlayerId;

  const AudioPlayerWidget({Key? key, required this.filePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AudioProvider>(
      create: (_) => AudioProvider()..loadAudio(filePath),
      builder: (context, child) {
        final provider = context.read<AudioProvider>();
        provider.loadAudio(filePath); // ⚠️ called again
        return const AudioPlayerContent();
      },
    );
  }
}

class AudioPlayerContent extends StatelessWidget {
  const AudioPlayerContent({Key? key}) : super(key: key);

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // If there's an error message, display it
            Selector<AudioProvider, String?>(
              selector: (_, provider) => provider.state.error,
              builder: (context, error, child) {
                if (error != null && error.isNotEmpty) {
                  return Center(
                    child: Text(
                      error,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                } else {
                  // Otherwise, display the audio player and waveform
                  return Column(
                    children: [
                      // Row with Waveform and Play/Pause Button
                      Row(
                        children: [
                          const PlayPauseButton(),
                          Expanded(child: const WaveformVisualizer()),
                        ],
                      ),

                      // Time Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Selector<AudioProvider, Duration>(
                            selector: (_, provider) => provider.state.position,
                            builder: (context, position, child) {
                              return Text(_formatDuration(position));
                            },
                          ),
                          Selector<AudioProvider, Duration>(
                            selector: (_, provider) => provider.state.duration,
                            builder: (context, duration, child) {
                              return Text(_formatDuration(duration));
                            },
                          ),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformVisualizer extends StatelessWidget {
  const WaveformVisualizer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<AudioProvider, List<int>>(
      selector: (_, provider) => provider.state.waveformData,
      builder: (context, waveformData, child) {
        final progress = context.select<AudioProvider, double>((provider) {
          final state = provider.state;
          return state.position.inMilliseconds /
              (state.duration.inMilliseconds == 0
                  ? 1
                  : state.duration.inMilliseconds);
        });

        return GestureDetector(
          onTapDown: (details) {
            final width = context.size!.width;
            final newProgress = details.localPosition.dx / width;
            final duration = context.read<AudioProvider>().state.duration;
            final newPosition = Duration(
              milliseconds: (newProgress * duration.inMilliseconds).toInt(),
            );
            context.read<AudioProvider>().seek(newPosition);
          },
          child: SizedBox(
            height: 30,
            child: CustomPaint(
              painter: WaveformPainter(
                waveformData: waveformData,
                // color: Theme.of(context).primaryColor,
                color: Colors.blue,
                progress: progress,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}

class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Selector<AudioProvider, bool>(
      selector: (_, provider) => provider.state.isPlaying,
      builder: (context, isPlaying, child) {
        return IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: Colors.blue,
          ),
          iconSize: 28,
          onPressed: () => context.read<AudioProvider>().togglePlay(),
        );
      },
    );
  }
}
