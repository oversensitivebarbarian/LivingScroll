import 'package:just_audio/just_audio.dart';

/// Thin wrapper over the audio player used by the Soundtracks section.
///
/// Real playback (just_audio) is a platform plugin a widget test cannot drive,
/// so tests swap [instance] for a fake that just records play/stop — mirroring
/// the `FilePickerService` pattern. The button glyph (Play/Stop) is driven by the
/// section's controller state, so the fake never needs to produce sound.
abstract class AudioPlayerService {
  /// The active player. Production uses [JustAudioPlayerService]; tests replace
  /// this before pumping the app (so the default is never constructed in tests).
  static AudioPlayerService instance = JustAudioPlayerService();

  /// Plays the file at [path] FROM THE BEGINNING, replacing whatever was playing.
  /// When [loop] is set the track repeats indefinitely (used for scene music);
  /// the Soundtracks editor plays once (loop off).
  Future<void> playFromStart(String path, {bool loop = false});

  /// Pauses playback, KEEPING the position so [resume] continues from here.
  Future<void> pause();

  /// Resumes playback paused by [pause].
  Future<void> resume();

  /// Stops playback (if any) and releases the loaded source.
  Future<void> stop();
}

/// Real player backed by `package:just_audio`. The underlying player is created
/// lazily on first use.
class JustAudioPlayerService implements AudioPlayerService {
  AudioPlayer? _player;
  AudioPlayer get _p => _player ??= AudioPlayer();

  /// The path currently loaded into the player. Replaying the SAME track skips
  /// re-opening the source (just seeks to the start) — fewer demuxer re-opens,
  /// which also avoids repeated benign mpv "file cache" logs on desktop.
  String? _loadedPath;

  @override
  Future<void> playFromStart(String path, {bool loop = false}) async {
    await _p.setLoopMode(loop ? LoopMode.one : LoopMode.off);
    if (_loadedPath != path) {
      await _p.setFilePath(path);
      _loadedPath = path;
    }
    await _p.seek(Duration.zero);
    // Fire-and-forget: play() completes only when playback ends; awaiting it
    // would block the caller for the whole track.
    _p.play();
  }

  @override
  Future<void> pause() async {
    await _player?.pause();
  }

  @override
  Future<void> resume() async {
    // play() resumes from the current (paused) position.
    _player?.play();
  }

  @override
  Future<void> stop() async {
    _loadedPath = null;
    await _player?.stop();
  }
}
