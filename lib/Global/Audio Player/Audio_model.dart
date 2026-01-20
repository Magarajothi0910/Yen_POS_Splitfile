// Audio_model.dart
class AudioState {
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<int> waveformData;
  final String? error;
  final double volume;
  final double speed;
  final bool isLoading;

  AudioState({
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.waveformData = const [],
    this.error,
    this.volume = 1.0,
    this.speed = 1.0,
    this.isLoading = false,
  });

  AudioState copyWith({
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<int>? waveformData,
    String? error,
    double? volume,
    double? speed,
    bool? isLoading,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      waveformData: waveformData ?? this.waveformData,
      error: error ?? this.error,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
