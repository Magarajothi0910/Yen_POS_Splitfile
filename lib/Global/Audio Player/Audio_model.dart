class AudioState {
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final Duration duration;
  final double volume;
  final double speed;
  String? error;
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
