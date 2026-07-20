import 'package:file_picker/file_picker.dart';

/// Thin wrapper over the native file pickers used by the Create flow.
///
/// The cover picker and the Import-data picker are native OS dialogs that a
/// widget test cannot drive. Tests swap [instance] for a fake that returns a
/// fixture path, mirroring the `MOCKS` contract in the Navigations specs — no
/// platform channel mocking required.
abstract class FilePickerService {
  /// The active picker. Production uses [DefaultFilePickerService]; tests
  /// replace this before pumping the app.
  static FilePickerService instance = DefaultFilePickerService();

  /// Pick a single image file (jpg/jpeg/png). Returns its path, or `null` if
  /// the user cancelled.
  Future<String?> pickImage();

  /// Pick a single JSON file. Returns its path, or `null` if cancelled.
  Future<String?> pickJson();

  /// Pick a single adventure archive — a portable `.ls` (full export) or `.lse`
  /// (elements export). Returns its path, or `null` if cancelled.
  Future<String?> pickArchive();

  /// Pick a single full-export archive (`.ls` only) — used by the Library import.
  /// Returns its path, or `null` if cancelled.
  Future<String?> pickLs();

  /// Pick a single audio file (one of the supported audio formats).
  /// Returns its path, or `null` if the user cancelled.
  Future<String?> pickAudio();

  /// Choose a destination path to SAVE a file under [fileName] (a native
  /// save-file dialog). Returns the chosen path, or `null` if cancelled. The
  /// caller writes the bytes to the returned path.
  Future<String?> saveFile({required String fileName});
}

/// Real picker backed by `package:file_picker`.
class DefaultFilePickerService implements FilePickerService {
  @override
  Future<String?> pickImage() => _pickSingle(['jpg', 'jpeg', 'png']);

  @override
  Future<String?> pickJson() => _pickSingle(['json']);

  @override
  Future<String?> pickArchive() => _pickSingle(['ls', 'lse']);

  @override
  Future<String?> pickLs() => _pickSingle(['ls']);

  @override
  Future<String?> pickAudio() =>
      _pickSingle(['mp3', 'aac', 'm4a', 'wav', 'flac', 'ogg', 'opus']);

  @override
  Future<String?> saveFile({required String fileName}) =>
      FilePicker.platform.saveFile(fileName: fileName);

  Future<String?> _pickSingle(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    return result?.files.single.path;
  }
}
