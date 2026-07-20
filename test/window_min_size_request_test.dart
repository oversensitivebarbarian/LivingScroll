// Verifies the app REQUESTS the minimum window size (640×480) on desktop and NOT
// on mobile — the Dart-side contract of `applyDesktopMinimumWindowSize`.
//
// NOTE: a pure-Dart test cannot drive the real OS window manager, so it cannot
// observe the native resize being blocked. The AUTHORITATIVE enforcement lives in
// the desktop runners (Linux gtk_widget_set_size_request, Windows WM_GETMINMAXINFO,
// macOS NSWindow.minSize); this test pins the cross-platform request that goes
// with them.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_scroll/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  const channel = MethodChannel('window_manager');

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Iterable<MethodCall> setMinCalls() =>
      calls.where((c) => c.method == 'setMinimumSize');

  for (final p in [
    TargetPlatform.linux,
    TargetPlatform.windows,
    TargetPlatform.macOS,
  ]) {
    test('desktop: requests minimum window size 640x480 on $p', () async {
      await applyDesktopMinimumWindowSize(platform: p);

      expect(
        setMinCalls(),
        hasLength(1),
        reason: 'setMinimumSize must be requested on $p',
      );
      final args = setMinCalls().first.arguments as Map;
      expect(args['width'], kMinimumWindowSize.width); // 640
      expect(args['height'], kMinimumWindowSize.height); // 480
    });
  }

  for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('mobile: does NOT request a minimum window size on $p', () async {
      await applyDesktopMinimumWindowSize(platform: p);
      // The OS (or the Android manifest <layout>) owns the window size there.
      expect(setMinCalls(), isEmpty);
    });
  }

  test('the declared minimum is 640x480', () {
    expect(kMinimumWindowSize, const Size(640, 480));
  });
}
