// audio_provider.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

import 'package:provider/provider.dart';

class AudioState {
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final double volume;
  final double speed;
  final String? error;
  final List<int> waveformData;

  AudioState({
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.speed = 1.0,
    this.error,
    this.waveformData = const [],
  });

  AudioState copyWith({
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    Duration? duration,
    double? volume,
    double? speed,
    String? error,
    List<int>? waveformData,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      error: error ?? this.error,
      waveformData: waveformData ?? this.waveformData,
    );
  }
}

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  AudioState _state = AudioState();
  static const String baseUrl = 'http://192.168.1.130:8888/fastapi/audios';

  AudioState get state => _state;
  AudioPlayer get player => _player;

  String? _currentId;
  //String? audioPlayerId;
  AudioProvider() {
    _initializeListeners();
  }

  void _initializeListeners() {
    _player.playerStateStream.listen((playerState) {
      final isPlaying = playerState.playing;
      final isLoading =
          playerState.processingState == ProcessingState.loading ||
              playerState.processingState == ProcessingState.buffering;

      if (playerState.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause(); // Automatically pause when the audio is complete
        _state = _state.copyWith(
            isPlaying: false,
            position: Duration.zero); // Update state to paused
      } else {
        _state = _state.copyWith(
          isPlaying: isPlaying,
          isLoading: isLoading,
          error: null,
        );
      }
      notifyListeners();
    });

    _player.positionStream.listen((position) {
      _state = _state.copyWith(position: position);
      notifyListeners();
    });

    _player.durationStream.listen((duration) {
      _state = _state.copyWith(duration: duration ?? Duration.zero);
      notifyListeners();
    });

    _player.volumeStream.listen((volume) {
      _state = _state.copyWith(volume: volume);
      notifyListeners();
    });

    _player.speedStream.listen((speed) {
      _state = _state.copyWith(speed: speed);
      notifyListeners();
    });
  }

  Future<bool> checkAudio(String? customId) async {
    try {
      await loadAudio(customId!); // Call loadAudio
      if (state.error == null) {
        //   audioPlayerId = customId;

        return true; // Audio loaded successfully
      } else {
        //  audioPlayerId = null;

        return false; // Error while loading audio
      }
    } catch (e) {
      //  audioPlayerId = null;

      return false; // Exception occurred while loading audio
    }
  }

  Future<void> loadAudio(String customId) async {
    if (_currentId == customId) return; // Avoid reloading if ID hasn't changed
    _currentId = customId;

    try {
      // Reset state for loading a new audio
      _state = AudioState();
      _state = _state.copyWith(isLoading: true, error: null);
      notifyListeners();

      final audioData = await _fetchAudio(customId);
      notifyListeners();

      if (audioData['content'] == null) {
        // If audio data is not available, show an error message
        //customId = null;
        notifyListeners();
        _state = _state.copyWith(
          isLoading: false,
          error: 'No audio available for this ID: $customId',
        );
        notifyListeners();
        return;
      }

      final List<int> audioBytes = _hexToBytes(audioData['content']);

      // Generate waveform data from audio bytes
      final waveformData = await _generateWaveformData(audioBytes);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${audioData['filename']}');
      await tempFile.writeAsBytes(audioBytes);

      await _player.setFilePath(tempFile.path);
      //  audioPlayerId = customId;
      // Successfully loaded audio
      _state = _state.copyWith(
        isLoading: false,
        waveformData: waveformData,
        error: null, // Clear error
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'No Audio Found',

        //print(e);
      );
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>> _fetchAudio(String customId) async {
    final response =
        await http.get(Uri.parse('$baseUrl/media/$customId/audio'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load audio');
    }
  }

  List<int> _hexToBytes(String hex) {
    var cleanHex = hex.replaceAll(' ', '');
    var bytes = <int>[];
    for (var i = 0; i < cleanHex.length; i += 2) {
      bytes.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  Future<List<int>> _generateWaveformData(List<int> audioBytes) async {
    // This is a simplified example - in a real app, you'd want to properly analyze the audio data
    // to generate accurate waveform data
    List<int> waveformData = [];
    for (int i = 0; i < audioBytes.length; i += 1000) {
      int amplitude = audioBytes[i] % 100; // Simplified amplitude calculation
      waveformData.add(amplitude);
    }
    return waveformData;
  }

  void togglePlay() {
    if (_state.isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void seek(Duration position) {
    _player.seek(position);
  }

  void setVolume(double volume) {
    _player.setVolume(volume);
  }

  void setSpeed(double speed) {
    _player.setSpeed(speed);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}

class WaveformPainter extends CustomPainter {
  final List<int> waveformData;
  final Color color;
  final double progress;

  WaveformPainter({
    required this.waveformData,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final backgroundPaint = Paint()
      // ..color = color.withOpacity(0.3)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final width = size.width / waveformData.length;
    final middle = size.height / 2;
    final progressWidth = size.width * progress;

    for (var i = 0; i < waveformData.length; i++) {
      final x = i * width;
      final amplitude = waveformData[i].toDouble();
      final height = (amplitude / 100) * (size.height / 2);

      final paint = x <= progressWidth ? progressPaint : backgroundPaint;

      canvas.drawLine(
        Offset(x, middle - height),
        Offset(x, middle + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveformData != waveformData;
  }
}

class AudioPlayerWidget extends StatelessWidget {
  final String customId;
  // final String? audioPlayerId;

  const AudioPlayerWidget({Key? key, required this.customId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AudioProvider>(
      create: (_) => AudioProvider()..loadAudio(customId),
      builder: (context, child) {
        final provider = context.read<AudioProvider>();
        provider
            .loadAudio(customId); // Ensure the provider updates for a new ID
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
