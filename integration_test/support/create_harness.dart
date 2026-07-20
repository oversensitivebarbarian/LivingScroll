import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/main.dart';
import 'package:living_scroll/services/audio_player_service.dart';
import 'package:living_scroll/services/file_picker_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Harness for the `create_new_*` navigation specs.
///
/// Redirects the user-files root to a temp dir (by swapping
/// [PathProviderPlatform.instance], since desktop path_provider bypasses
/// channels) and replaces [FilePickerService.instance] with a fake that returns
/// fixture paths — the `MOCKS` contract from the specs, without native dialogs.
class CreateHarness {
  late final Directory _supportDir;
  PathProviderPlatform? _previousPlatform;
  FilePickerService? _previousPicker;
  AudioPlayerService? _previousPlayer;

  final _FakeFilePicker _picker = _FakeFilePicker();
  final _FakeAudioPlayer _player = _FakeAudioPlayer();

  /// Absolute path to a read-only repo asset under `Test_Assets/`.
  static String asset(String name) =>
      '${Directory.current.path}/Test_Assets/$name';

  Directory get projectsDir => Directory('${_supportDir.path}/Projects');

  /// {Settings} root: `<support>/Settings`.
  Directory get settingsDir => Directory('${_supportDir.path}/Settings');

  /// {Adventures} root: `<support>/Adventures` (unpacked `.ls` archives).
  Directory get adventuresDir => Directory('${_supportDir.path}/Adventures');

  /// {Saves} root: `<support>/Saves` (in-progress playthroughs).
  Directory get savesDir => Directory('${_supportDir.path}/Saves');

  /// {Finished} root: `<support>/Finished` (completed read-only adventures).
  Directory get finishedDir => Directory('${_supportDir.path}/Finished');

  /// Scratch dir for download-only artifacts (`.lse`): `<support>/.export_tmp`.
  Directory get exportTmpDir => Directory('${_supportDir.path}/.export_tmp');

  /// The path of the last track the fake player was asked to play (null = none).
  String? get lastPlayed => _player.lastPlayed;

  /// Whether the last play request asked the track to loop.
  bool get lastPlayLooped => _player.lastLoop;

  /// How many times the fake player was asked to pause / resume / stop.
  int get audioPauseCount => _player.pauseCount;
  int get audioResumeCount => _player.resumeCount;
  int get audioStopCount => _player.stopCount;

  /// Seed `{Settings}/overrides.json` before pumping the app (e.g. autoplay off).
  Future<void> writeOverrides(Map<String, dynamic> json) async {
    await settingsDir.create(recursive: true);
    await File('${settingsDir.path}/overrides.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(json),
    );
  }

  /// The cover image returned by the next image pick (null = user cancels).
  set coverPath(String? path) => _picker.imagePath = path;

  /// The JSON file returned by the next Import-data pick (Create-new flow).
  set jsonPath(String? path) => _picker.jsonPath = path;

  /// The `.ls`/`.lse` archive returned by the next Adventure-settings Import pick.
  set archivePath(String? path) => _picker.archivePath = path;

  /// The `.ls` archive returned by the next Library import pick.
  set lsPath(String? path) => _picker.lsPath = path;

  /// The audio file returned by the next Add-soundtrack pick.
  set audioPath(String? path) => _picker.audioPath = path;

  /// The destination the next Save-file dialog returns (null = user cancels).
  set saveFilePath(String? path) => _picker.saveFilePath = path;

  Future<void> setUp() async {
    _supportDir =
        await Directory.systemTemp.createTemp('living_scroll_create_');
    // FIXTURES: {Projects} exists but is empty (state: empty).
    await projectsDir.create(recursive: true);
    await Directory('${_supportDir.path}/Settings').create(recursive: true);

    _previousPlatform = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(_supportDir.path);

    _previousPicker = FilePickerService.instance;
    FilePickerService.instance = _picker;

    // Swap the audio player for a fake so the real just_audio plugin is never
    // touched; the Play/Stop glyph is driven by controller state, not the fake.
    _previousPlayer = AudioPlayerService.instance;
    AudioPlayerService.instance = _player;
  }

  Future<void> tearDown() async {
    if (_previousPlatform != null) {
      PathProviderPlatform.instance = _previousPlatform!;
    }
    if (_previousPicker != null) FilePickerService.instance = _previousPicker!;
    if (_previousPlayer != null) AudioPlayerService.instance = _previousPlayer!;
    if (await _supportDir.exists()) {
      await _supportDir.delete(recursive: true);
    }
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const LivingScrollApp());
    await tester.pumpAndSettle();
  }

  // --- EFFECTS ------------------------------------------------------------

  /// The project directories currently under `{Projects}`.
  List<Directory> projects() => projectsDir.existsSync()
      ? (projectsDir.listSync().whereType<Directory>().toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : const [];

  /// The single created project directory (fails if there is not exactly one).
  Directory soleProject() {
    final dirs = projects();
    expect(dirs.length, 1, reason: 'expected exactly one project directory');
    return dirs.single;
  }

  /// Decoded LivingScroll.json of the given project directory.
  Map<String, dynamic> readDocument(Directory project) {
    final file = File('${project.path}/LivingScroll.json');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }
}

class _FakeFilePicker implements FilePickerService {
  String? imagePath;
  String? jsonPath;
  String? archivePath;
  String? lsPath;
  String? audioPath;
  String? saveFilePath;

  @override
  Future<String?> pickImage() async => imagePath;

  @override
  Future<String?> pickJson() async => jsonPath;

  @override
  Future<String?> pickArchive() async => archivePath;

  @override
  Future<String?> pickLs() async => lsPath;

  @override
  Future<String?> pickAudio() async => audioPath;

  @override
  Future<String?> saveFile({required String fileName}) async => saveFilePath;
}

/// Records play/pause/resume/stop calls without touching a real player (glyph
/// state is driven by the screen/controller, so the fake only needs to not throw).
class _FakeAudioPlayer implements AudioPlayerService {
  String? lastPlayed;
  bool lastLoop = false;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;

  @override
  Future<void> playFromStart(String path, {bool loop = false}) async {
    lastPlayed = path;
    lastLoop = loop;
  }

  @override
  Future<void> pause() async => pauseCount++;

  @override
  Future<void> resume() async => resumeCount++;

  @override
  Future<void> stop() async => stopCount++;
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this._support);

  final String _support;

  @override
  Future<String?> getApplicationSupportPath() async => _support;
}
