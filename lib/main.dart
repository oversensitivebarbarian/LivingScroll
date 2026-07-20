import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'home_shell.dart';
import 'l10n/app_localizations.dart';
import 'settings/settings_overrides.dart';
import 'settings/settings_scope.dart';
import 'settings/settings_store.dart';
import 'widgets/rail_state.dart';

void main() {
  // media_kit (just_audio's desktop backend) and mpv emit a couple of harmless
  // console lines we cannot configure away: mpv logs "lavf: Failed to create
  // file cache." at error level because media_kit hard-enables `cache-on-disk`
  // even for short LOCAL audio (the cache is pointless there and mpv falls back
  // gracefully), and media_kit prints a one-off NativeReferenceHolder line. The
  // lowest selectable mpv log level is `error`, so neither can be silenced via
  // the API. Drop ONLY these two known-benign patterns here, in a print zone, so
  // every other (genuinely useful) log still reaches the console.
  // Binding init, window setup and runApp all live in the SAME (custom) zone so
  // there is no "Zone mismatch" between binding creation and runApp.
  runZoned(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await applyDesktopMinimumWindowSize();
      // Register the media_kit backend so just_audio can play on the desktop
      // platforms without a built-in just_audio implementation (Linux and
      // Windows). Guarded to those two; mobile and macOS keep their native
      // just_audio backend. Native libs come from media_kit_libs_linux /
      // media_kit_libs_windows_audio (see pubspec).
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.windows)) {
        JustAudioMediaKit.ensureInitialized(linux: true, windows: true);
      }
      runApp(const LivingScrollApp());
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (_isBenignMediaKitLog(line)) return;
        parent.print(zone, line);
      },
    ),
  );
}

/// The app's MINIMUM window size in LOGICAL pixels.
const Size kMinimumWindowSize = Size(640, 480);

/// Requests the desktop MINIMUM window size via window_manager, so the window
/// cannot be resized below the UI's verified-safe floor ([kMinimumWindowSize]).
///
/// The AUTHORITATIVE enforcement is NATIVE, in each desktop runner (Linux
/// `gtk_widget_set_size_request`, Windows `WM_GETMINMAXINFO`, macOS
/// `NSWindow.minSize`) — window_manager's Dart-side hint did not reliably apply on
/// Linux, so the runners are what actually block the resize. This call is the
/// cross-platform belt-and-suspenders. No-op on web/mobile (the OS / Android
/// manifest `<layout>` owns the window there).
///
/// [platform] overrides the runtime target (for tests).
Future<void> applyDesktopMinimumWindowSize({TargetPlatform? platform}) async {
  if (kIsWeb) return;
  final p = platform ?? defaultTargetPlatform;
  if (p != TargetPlatform.linux &&
      p != TargetPlatform.windows &&
      p != TargetPlatform.macOS) {
    return;
  }
  await windowManager.ensureInitialized();
  await windowManager.setMinimumSize(kMinimumWindowSize);
}

/// Whether [line] is one of the two known-benign media_kit/mpv console lines we
/// suppress (see [main]). Kept deliberately narrow so real errors still print.
bool _isBenignMediaKitLog(String line) =>
    line.contains('Failed to create file cache') ||
    line.startsWith('media_kit: NativeReferenceHolder:');

/// Root of the LivingScroll application.
///
/// Wires up Material 3 theming and the full set of supported locales
/// (English, German, French, Portuguese, Spanish, Polish, Chinese, Japanese)
/// generated from the ARB files in `lib/l10n`. Language and display-mode
/// overrides are loaded from `{Settings}/overrides.json` and applied here as
/// the app's [MaterialApp.locale] and [MaterialApp.themeMode]; the Settings
/// screen mutates them through the [SettingsScope].
class LivingScrollApp extends StatefulWidget {
  const LivingScrollApp({super.key});

  @override
  State<LivingScrollApp> createState() => _LivingScrollAppState();
}

class _LivingScrollAppState extends State<LivingScrollApp> {
  static const _seedColor = Color(0xFF6750A4);

  final SettingsStore _store = const SettingsStore();
  SettingsOverrides _overrides = const SettingsOverrides();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    RailState.extended.removeListener(_onRailChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await _store.load();
    if (!mounted) return;
    // Restore the persisted rail (the "roller") open/collapsed state BEFORE
    // listening, so this initial set never re-triggers a save.
    RailState.extended.value = loaded.railExtendedOn;
    RailState.extended.addListener(_onRailChanged);
    setState(() => _overrides = loaded);
  }

  /// The rail is toggled app-wide via [RailState]; persist the new state to
  /// overrides.json (through [_apply], which composes the stub from RailState).
  void _onRailChanged() => _apply(_overrides);

  Future<void> _apply(SettingsOverrides overrides) async {
    // RailState is the source of truth for the rail stub — compose it here so a
    // settings-form save (whose overrides carry no rail stub) never drops it,
    // and a rail toggle persists the just-changed value.
    final effective = SettingsOverrides(
      lang: overrides.lang,
      mode: overrides.mode,
      autoplay: overrides.autoplay,
      railExtended: RailState.extended.value ? true : null,
    );
    setState(() => _overrides = effective);
    await _store.save(effective);
  }

  ThemeMode get _themeMode => switch (_overrides.mode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Locale? get _locale =>
      _overrides.lang == null ? null : Locale(_overrides.lang!);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: const ValueKey('app.root'),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _locale,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      ),
      // SettingsScope wraps the Navigator (above all routes) so PUSHED routes —
      // the game screen and its scene-preview Play view — can read the overrides
      // too, not just the Home-shell destinations.
      builder: (context, child) => SettingsScope(
        overrides: _overrides,
        onChanged: _apply,
        child: child!,
      ),
      home: const HomeShell(),
    );
  }
}
