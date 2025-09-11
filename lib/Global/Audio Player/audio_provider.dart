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
          position: Duration.zero,
        ); // Update state to paused
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

  Future<void> loadAudio(String filePath) async {
    if (_currentId == filePath) return; // Avoid reloading if same path
    _currentId = filePath;

    try {
      _state = AudioState();
      _state = _state.copyWith(isLoading: true, error: null);
      notifyListeners();

      await _player.setFilePath(filePath); // Directly load from local path

      // Generate fake waveform data for now if needed
      final fileBytes = await File(filePath).readAsBytes();
      final waveformData = await _generateWaveformData(fileBytes);

      _state = _state.copyWith(
        isLoading: false,
        waveformData: waveformData,
        error: null,
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'No audio file found. Please add an audio file to play.',
      );
    }

    notifyListeners();
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
