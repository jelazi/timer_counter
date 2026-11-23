import 'package:flutter/material.dart';

import '../../../core/theme/desktop_theme.dart';

/// Small macOS-style toggle (the size used in System Settings rows).
class MacSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const MacSwitch({super.key, required this.value, required this.onChanged});

  static const double _width = 32;
  static const double _height = 19;
  static const double _inset = 1.5;

  @override
  Widget build(BuildContext context) {
    final mac = MacColors.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onChanged != null;
    final thumb = _height - _inset * 2;

    return Semantics(
      toggled: value,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? () => onChanged!(!value) : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: _width,
              height: _height,
              decoration: BoxDecoration(
                color: value ? accent : (isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000)),
                borderRadius: BorderRadius.circular(_height / 2),
                border: Border.all(color: value ? Colors.transparent : mac.label.withValues(alpha: 0.06), width: 0.5),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: thumb,
                  height: thumb,
                  margin: const EdgeInsets.all(_inset - 0.5),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 2, offset: Offset(0, 0.5))],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
