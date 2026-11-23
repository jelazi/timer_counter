import 'package:flutter/material.dart';

import '../../../core/theme/desktop_theme.dart';
import 'window_drag_area.dart';

/// Toolbar at the top of a desktop content pane: title on the left, optional
/// centered control, actions on the right. Doubles as the window drag area.
class PaneHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? center;
  final List<Widget> actions;

  const PaneHeader({super.key, required this.title, this.subtitle, this.center, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final mac = MacColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    final titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.titleLarge, overflow: TextOverflow.ellipsis, maxLines: 1),
        if (subtitle != null) Text(subtitle!, style: textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
    );

    final actionRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 8), actions[i]],
      ],
    );

    return WindowDragArea(
      child: Container(
        height: DesktopTheme.toolbarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: mac.content,
          border: Border(bottom: BorderSide(color: mac.separator)),
        ),
        child: center == null
            ? Row(
                children: [
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: titleBlock),
                  ),
                  const SizedBox(width: 12),
                  actionRow,
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Align(alignment: Alignment.centerLeft, child: titleBlock),
                  ),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: center),
                  Expanded(
                    child: Align(alignment: Alignment.centerRight, child: actionRow),
                  ),
                ],
              ),
      ),
    );
  }
}
