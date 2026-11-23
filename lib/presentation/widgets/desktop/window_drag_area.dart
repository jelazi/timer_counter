import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/utils/platform_utils.dart';

/// Lets the user drag the window by [child]; a no-op off native desktop.
class WindowDragArea extends StatelessWidget {
  final Widget child;

  const WindowDragArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) => PlatformUtils.isDesktop ? DragToMoveArea(child: child) : child;
}
