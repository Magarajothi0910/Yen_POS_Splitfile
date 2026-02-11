import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_waveforms/audio_waveforms.dart' as audio_waveforms;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// State notifier to manage voice recorder state
class VoiceRecorderState extends ChangeNotifier {
  final AudioRecorder _record = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

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
  Duration _playbackPosition = Duration.zero;
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
  Duration get playbackDuration => _playbackPosition;
  Duration get totalDuration => _totalDuration;
  audio_waveforms.RecorderController? get recorder => recorderController;
  audio_waveforms.PlayerController? get player => playerController;

  VoiceRecorderState() {
    _initControllers();
    _setupPlayerListeners();
  }

  void _initControllers() {
    recorderController = audio_waveforms.RecorderController()
      ..androidEncoder = audio_waveforms.AndroidEncoder.aac
      ..iosEncoder =
          audio_waveforms.IosEncoder.kAudioFormatMPEG4AAC; // ← correct

    playerController = audio_waveforms.PlayerController();
  }

  void _setupPlayerListeners() {
    _player.positionStream.listen((position) {
      _playbackPosition = position;
      notifyListeners();
    });

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _playbackPosition = _totalDuration;
        playerController?.stopPlayer();
        notifyListeners();
      }
    });
  }

  Future<void> startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final appDocDir = await getApplicationDocumentsDirectory();
    _filePath =
        '${appDocDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _record.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc, // or AudioEncoder.opus, pcm16bits, etc.
        bitRate: 128000, // in bits per second
        sampleRate: 44100, // note: sampleRate (not samplingRate)
        numChannels: 1, // mono is usually enough for voice
      ),
      path: _filePath,
    );
    await recorderController?.record();

    _elapsedDuration = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedDuration = Duration(seconds: timer.tick);
      notifyListeners();
    });

    _maxDurationTimer = Timer(_maxDuration, () {
      if (_isRecording) stopRecording();
    });

    _isRecording = true;
    _isPaused = false;
    _totalDuration = Duration.zero;
    notifyListeners();
  }

  Future<void> stopRecording() async {
    await _record.stop();
    await recorderController?.stop();

    _recordingTimer?.cancel();
    _maxDurationTimer?.cancel();
    _recordingTimer = null;
    _maxDurationTimer = null;

    _isRecording = false;
    _isLocked = false;
    _totalDuration = _elapsedDuration;
    _elapsedDuration = Duration.zero;
    notifyListeners();

    // Save path to Hive
    var audioBox = Hive.box<String>('audioFiles');
    await audioBox.add(_filePath);

    await _preparePlayback();
  }

  Future<void> _preparePlayback() async {
    if (_filePath.isEmpty) return;

    try {
      await _player.setFilePath(_filePath);
      _totalDuration = _player.duration ?? Duration.zero;
      _playbackPosition = Duration.zero;

      await playerController?.preparePlayer(path: _filePath, noOfSamples: 100);
      notifyListeners();
    } catch (e) {
      debugPrint('Prepare playback error: $e');
    }
  }

  Future<void> togglePlayback() async {
    if (_filePath.isEmpty) return;

    try {
      if (_isPlaying) {
        await pausePlayback();
        return;
      }

      // Reset to start if finished
      if (_playbackPosition >= (_player.duration ?? Duration.zero)) {
        await _player.seek(Duration.zero);
        _playbackPosition = Duration.zero;
        await playerController?.stopPlayer();
        await playerController?.preparePlayer(path: _filePath);
      }

      await _player.play();
      await playerController?.startPlayer();

      _isPlaying = true;
      _isPaused = false;
      notifyListeners();
    } catch (e) {
      _isPlaying = false;
      _isPaused = false;
      await _player.pause();
      await playerController?.pausePlayer();
      notifyListeners();
      debugPrint('Playback error: $e');
    }
  }

  Future<void> pausePlayback() async {
    await _player.pause();
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
    _record.dispose();
    _player.dispose();
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

  const VoiceRecorder({required this.onRecordingComplete, super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceRecorderState(),
      child: VoiceRecorderView(onRecordingComplete: onRecordingComplete),
    );
  }
}

class VoiceRecorderView extends StatelessWidget {
  final Function(String) onRecordingComplete;

  const VoiceRecorderView({required this.onRecordingComplete, super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceRecorderState>(
      builder: (context, state, child) {
        return Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Play/Pause button when not recording and have file
                      if (!state.isRecording && state.filePath.isNotEmpty)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            state.isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 22,
                            color: Colors.blue,
                          ),
                          onPressed: state.togglePlayback,
                        )
                      else
                        const SizedBox(width: 22),

                      // Waveform
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: state.isRecording
                              ? audio_waveforms.AudioWaveforms(
                                  recorderController: state.recorder!,
                                  size: const Size(double.infinity, 40),
                                  waveStyle: const audio_waveforms.WaveStyle(
                                    waveColor: Colors.blue,
                                    extendWaveform: true,
                                    showMiddleLine: false,
                                  ),
                                )
                              : state.filePath.isNotEmpty
                              ? audio_waveforms.AudioFileWaveforms(
                                  playerController: state.player!,
                                  size: const Size(double.infinity, 40),
                                  enableSeekGesture: true,
                                  waveformType:
                                      audio_waveforms.WaveformType.fitWidth,
                                  playerWaveStyle:
                                      const audio_waveforms.PlayerWaveStyle(
                                        fixedWaveColor: Colors.grey,
                                        liveWaveColor: Colors.blue,
                                        showBottom: false,
                                      ),
                                )
                              : const SizedBox(),
                        ),
                      ),

                      // Mic / Stop button
                      GestureDetector(
                        onTap: () async {
                          if (!state.isRecording) {
                            await state.startRecording();
                          } else {
                            await state.stopRecording();
                            onRecordingComplete(state.filePath);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: state.isRecording ? Colors.red : Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            state.isRecording ? Icons.stop : Icons.mic,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Duration text
                Text(
                  state.isRecording
                      ? "${state.formatDuration(state.elapsedDuration)} / ${state.formatDuration(state.maxDuration)}"
                      : state.filePath.isNotEmpty
                      ? "${state.formatDuration(state.playbackDuration)} / ${state.formatDuration(state.totalDuration)}"
                      : "",
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
