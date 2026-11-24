import 'dart:io';

import 'package:flutter/foundation.dart';

/// Utility class for platform detection.
class PlatformUtils {
  PlatformUtils._();

  /// True on Android or iOS.
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// True on macOS, Windows, or Linux.
  static bool get isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// True when running in a web browser.
  static bool get isWeb => kIsWeb;

  /// Short platform name used to tell devices apart in synced records.
  static String get deviceLabel {
    if (kIsWeb) return 'Web';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    return Platform.operatingSystem;
  }
}
