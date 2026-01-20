// audio_provider.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'audio_provider.dart';
import 'wave_screen.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String filePath;
  final VoidCallback? onDispose;

  const AudioPlayerWidget({Key? key, required this.filePath, this.onDispose})
    : super(key: key);

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AudioProvider>(
      create: (_) => AudioProvider(),
      child: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          // Load audio when widget is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (widget.filePath.isNotEmpty) {
              audioProvider.loadAudio(widget.filePath);
            }
          });

          return const AudioPlayerContent();
        },
      ),
    );
  }
}

class AudioPlayerContent extends StatelessWidget {
  const AudioPlayerContent({Key? key}) : super(key: key);

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: EdgeInsets.zero, // 🔴 IMPORTANT
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        height: 56, // 🔴 fixed height
        width: 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const PlayPauseButton(),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔹 WAVEFORM
                  SizedBox(
                    height: 32,
                    width: double.infinity,
                    child: const WaveformVisualizer(),
                  ),

                  const SizedBox(height: 2),

                  // 🔹 TIME
                  Selector<AudioProvider, Duration>(
                    selector: (_, p) => p.state.position,
                    builder: (_, pos, __) {
                      final dur = context.read<AudioProvider>().state.duration;

                      return Text(
                        "${_format(pos)} / ${_format(dur)}",
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
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
          if (state.duration.inMilliseconds == 0) return 0;
          return state.position.inMilliseconds / state.duration.inMilliseconds;
        });

        return GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || !box.hasSize) return;

            final width = box.size.width;
            final newProgress = details.localPosition.dx / width;

            final duration = context.read<AudioProvider>().state.duration;

            final newPosition = Duration(
              milliseconds: (newProgress * duration.inMilliseconds).toInt(),
            );

            context.read<AudioProvider>().seek(newPosition);
          },
          child: SizedBox(
            height: 30,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                waveformData: waveformData,
                color: Colors.blue,
                progress: progress,
              ),
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
