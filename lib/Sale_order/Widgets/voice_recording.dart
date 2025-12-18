import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart' as flutter_sound;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart' as audio_waveforms;
import 'package:provider/provider.dart';

// State notifier to manage voice recorder state
class VoiceRecorderState extends ChangeNotifier {
  flutter_sound.FlutterSoundRecorder? _recorder;
  flutter_sound.FlutterSoundPlayer? _player;
  audio_waveforms.RecorderController? recorderController;
  audio_waveforms.PlayerController? playerController;
  Timer? _recordingTimer;
  Timer? _maxDurationTimer;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _isLocked = false;
  bool _showLockIcon = false;
  String _filePath = '';
  Duration _maxDuration = const Duration(minutes: 2);
  Duration _elapsedDuration = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Getters
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isLocked => _isLocked;
  bool get showLockIcon => _showLockIcon;
  String get filePath => _filePath;
  Duration get maxDuration => _maxDuration;
  Duration get elapsedDuration => _elapsedDuration;
  Duration get playbackDuration => _playbackDuration;
  Duration get totalDuration => _totalDuration;
  audio_waveforms.RecorderController? get recorder => recorderController;
  audio_waveforms.PlayerController? get player => playerController;

  VoiceRecorderState() {
    _initializeRecorder();
  }
  Future<void> _initializeRecorder() async {
    try {
      _recorder = flutter_sound.FlutterSoundRecorder();
      _player = flutter_sound.FlutterSoundPlayer();

      recorderController = audio_waveforms.RecorderController()
        ..androidEncoder = audio_waveforms.AndroidEncoder.aac
        ..iosEncoder = audio_waveforms.IosEncoder.kAudioFormatMPEG4AAC;

      playerController = audio_waveforms.PlayerController();

      playerController?.onCurrentDurationChanged.listen((duration) {
        _playbackDuration = Duration(milliseconds: duration);
        notifyListeners();
      });

      playerController?.onPlayerStateChanged.listen((state) {
        if (state == audio_waveforms.PlayerState.stopped) {
          _isPlaying = false;
          _playbackDuration = Duration.zero;
          notifyListeners();
        }
      });
    } catch (e) {}
  }

  Future<void> startRecording() async {
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      return;
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    _filePath =
        '${appDocDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder?.openRecorder();
    await _recorder?.startRecorder(
      toFile: _filePath,
      codec: flutter_sound.Codec.aacADTS,
    );

    recorderController?.record();

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedDuration = Duration(seconds: timer.tick);
      notifyListeners();
    });

    _maxDurationTimer = Timer(_maxDuration, () {
      if (_isRecording) {
        stopRecording();
      }
    });

    _isRecording = true;
    _isPaused = false;
    _totalDuration = Duration.zero;
    notifyListeners();
  }

  Future<void> stopRecording() async {
    await _recorder?.stopRecorder();
    recorderController?.stop();

    _recordingTimer?.cancel();
    _maxDurationTimer?.cancel();
    _recordingTimer = null;
    _maxDurationTimer = null;

    _isRecording = false;
    _isLocked = false;
    _totalDuration = _elapsedDuration;
    _elapsedDuration = Duration.zero;
    notifyListeners();

    var audioBox = Hive.box<String>('audioFiles');
    await audioBox.add(_filePath);
    await playerController?.stopPlayer();
    playerController = audio_waveforms.PlayerController();
    await _preparePlayback();
  }

  Future<void> _preparePlayback() async {
    if (_filePath.isEmpty) {
      return;
    }

    try {
      await playerController?.preparePlayer(path: _filePath, noOfSamples: 100);

      final durationInMillis = await playerController?.getDuration();
      _totalDuration = Duration(milliseconds: durationInMillis ?? 0);
      _playbackDuration = Duration.zero;
      notifyListeners();
    } catch (e) {}
  }

  Future<void> togglePlayback() async {
    try {
      // If currently playing, pause
      if (_isPlaying) {
        await pausePlayback();
        return;
      }

      // If at end of playback, reset
      if (_playbackDuration >= _totalDuration) {
        _playbackDuration = Duration.zero;
        await playerController?.stopPlayer();
        await _preparePlayback();
      }

      // Start playback
      await startPlayback();
    } catch (e) {
      // Reset state
      _isPlaying = false;
      _isPaused = false;
      await playerController?.stopPlayer();
      notifyListeners();
    }
  }

  Future<void> startPlayback() async {
    if (_filePath.isEmpty) return;

    try {
      // Ensure player is prepared
      if (playerController?.playerState !=
          audio_waveforms.PlayerState.initialized) {
        await _preparePlayback();
      }

      // Start player
      await playerController?.startPlayer();

      // Listen for player state changes
      playerController?.onPlayerStateChanged.listen((state) {
        if (state == audio_waveforms.PlayerState.stopped) {
          _isPlaying = false;
          _isPaused = false;
          _playbackDuration = _totalDuration;
          notifyListeners();
        }
      });

      // Update state
      _isPlaying = true;
      _isPaused = false;
      notifyListeners();
    } catch (e) {
      // Reset state on error
      _isPlaying = false;
      _isPaused = false;
      await playerController?.stopPlayer();
      notifyListeners();
    }
  }

  Future<void> pausePlayback() async {
    await playerController?.pausePlayer();
    _isPlaying = false;
    _isPaused = true;
    notifyListeners();
  }

  void toggleLock() {
    _isLocked = !_isLocked;
    _showLockIcon = false;
    notifyListeners();
  }

  void setShowLockIcon(bool show) {
    _showLockIcon = show;
    notifyListeners();
  }

  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _player?.closePlayer();
    recorderController?.dispose();
    playerController?.dispose();
    _recordingTimer?.cancel();
    _maxDurationTimer?.cancel();
    super.dispose();
  }
}

// Voice Recorder Widget
class VoiceRecorder extends StatelessWidget {
  final Function(String) onRecordingComplete;

  const VoiceRecorder({required this.onRecordingComplete, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceRecorderState(),
      child: VoiceRecorderView(onRecordingComplete: onRecordingComplete),
    );
  }
}

// Voice Recorder View
class VoiceRecorderView extends StatelessWidget {
  final Function(String) onRecordingComplete;

  const VoiceRecorderView({required this.onRecordingComplete, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceRecorderState>(
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(255, 204, 204, 204),
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          if (!state.isRecording && state.filePath.isNotEmpty)
                            IconButton(
                              onPressed: state.togglePlayback,
                              icon: Icon(
                                state.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              color: Colors.blue,
                              iconSize: 30,
                            )
                          else
                            const SizedBox(width: 28),
                          Expanded(
                            child: Container(
                              height: 55,
                              child: state.isRecording
                                  ? audio_waveforms.AudioWaveforms(
                                      recorderController: state.recorder!,
                                      size: Size(double.infinity, 50),
                                      waveStyle:
                                          const audio_waveforms.WaveStyle(
                                            waveColor: Colors.blue,
                                            extendWaveform: true,
                                            showMiddleLine: false,
                                          ),
                                    )
                                  : state.filePath.isNotEmpty
                                  ? audio_waveforms.AudioFileWaveforms(
                                      size: Size(double.infinity, 50),
                                      playerController: state.player!,
                                      enableSeekGesture: true,
                                      waveformType:
                                          audio_waveforms.WaveformType.fitWidth,
                                      playerWaveStyle:
                                          const audio_waveforms.PlayerWaveStyle(
                                            fixedWaveColor: Colors.grey,
                                            liveWaveColor: Colors.blue,
                                            seekLineColor: Colors.red,
                                            showBottom: false,
                                          ),
                                    )
                                  : const SizedBox(),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (!state.isRecording) {
                                state.startRecording();
                              } else if (!state.isLocked) {
                                state.stopRecording();
                                onRecordingComplete(state.filePath);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: state.isRecording
                                    ? Colors.red
                                    : Colors.blue,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                state.isRecording ? Icons.stop : Icons.mic,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      state.isRecording
                          ? "${state.formatDuration(state.elapsedDuration)} / ${state.formatDuration(state.maxDuration)}"
                          : state.filePath.isNotEmpty
                          ? "${state.formatDuration(state.playbackDuration)} / ${state.formatDuration(state.totalDuration)}"
                          : "",
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AudioList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var audioBox = Hive.box<String>('audioFiles');

    return ValueListenableBuilder(
      valueListenable: audioBox.listenable(),
      builder: (context, Box<String> box, _) {
        if (box.isEmpty) {
          return const Text("No recordings available");
        }

        return ListView.builder(
          itemCount: box.length,
          itemBuilder: (context, index) {
            final filePath = box.getAt(index) ?? "";
            return ListTile(
              title: Text("Recording ${index + 1}"),
              subtitle: Text(filePath),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () async {
                  await box.deleteAt(index);
                },
              ),
            );
          },
        );
      },
    );
  }
}
