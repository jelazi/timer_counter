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
}
