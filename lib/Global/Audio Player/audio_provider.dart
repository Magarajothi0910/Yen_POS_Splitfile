// audio_provider.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';

import 'Audio_model.dart';

class AudioProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  AudioState _state = AudioState();

  AudioState get state => _state;
  AudioPlayer get player => _player;

  String? _currentFilePath;

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
        _player.pause();
        _state = _state.copyWith(isPlaying: false, position: Duration.zero);
        notifyListeners();
      } else {
        _state = _state.copyWith(
          isPlaying: isPlaying,
          isLoading: isLoading,
          error: null,
        );
        notifyListeners();
      }
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

  Future<void> loadAudio(String filePath) async {
    if (_currentFilePath == filePath && filePath.isNotEmpty) {
      return;
    }

    _currentFilePath = filePath;

    try {
      _state = AudioState(
        isLoading: true,
        error: null,
        position: Duration.zero,
        duration: Duration.zero,
      );
      notifyListeners();

      await _player.stop();
      await _player.setFilePath(filePath);

      final file = File(filePath);
      if (await file.exists()) {
        final fileBytes = await file.readAsBytes();
        final waveformData = await _generateWaveformData(fileBytes);

        _state = AudioState(
          isLoading: false,
          waveformData: waveformData,
          error: null,
          position: Duration.zero,
          duration: _player.duration ?? Duration.zero,
          isPlaying: false,
        );
      } else {
        _state = AudioState(
          isLoading: false,
          error: 'Audio file not found',
          position: Duration.zero,
          duration: Duration.zero,
        );
      }
    } catch (e) {
      print("Error loading audio: $e");
      _state = AudioState(
        isLoading: false,
        error: 'Failed to load audio file',
        position: Duration.zero,
        duration: Duration.zero,
      );
    }

    notifyListeners();
  }

  /// 🔥 COMPLETE AUDIO RESET - Call this when placing held order
  Future<void> completeAudioReset() async {
    try {
      // 1. Stop playback immediately
      await _player.stop();

      // 2. Seek to beginning
      await _player.seek(Duration.zero);

      // 3. Reset to empty state (as if new)
      _state = AudioState(
        position: Duration.zero,
        duration: Duration.zero,
        isPlaying: false,
        isLoading: false,
        waveformData: [],
        error: null,
        volume: 1.0,
        speed: 1.0,
      );

      // 4. Clear current file path reference
      _currentFilePath = null;

      // 5. Notify listeners to rebuild UI
      notifyListeners();

      print("✅ Audio completely reset - ready for new recording");
    } catch (e) {
      print("❌ Error in completeAudioReset: $e");
      // Force reset state even if error occurs
      _state = AudioState();
      _currentFilePath = null;
      notifyListeners();
    }
  }

  Future<List<int>> _generateWaveformData(List<int> audioBytes) async {
    List<int> waveformData = [];
    final totalSamples = audioBytes.length ~/ 2;

    if (totalSamples == 0) return [];

    final step = totalSamples ~/ 100;
    for (int i = 0; i < totalSamples && i < 100 * step; i += step) {
      final amplitude = (audioBytes[i] & 0xFF).abs();
      waveformData.add(amplitude % 100);
    }

    return waveformData.isNotEmpty ? waveformData : [50];
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
    _player.setVolume(volume.clamp(0.0, 1.0));
  }

  void setSpeed(double speed) {
    _player.setSpeed(speed.clamp(0.5, 2.0));
  }

  Future<void> stop() async {
    await _player.stop();
    _state = _state.copyWith(isPlaying: false, position: Duration.zero);
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
