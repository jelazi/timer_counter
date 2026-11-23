import 'package:flutter/material.dart';

import '../../core/utils/platform_utils.dart';
import 'desktop/mac_switch.dart';

/// [SwitchListTile] on mobile, a compact row with a [MacSwitch] on desktop.
class AppSwitchTile extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;

  const AppSwitchTile({super.key, this.title, this.subtitle, this.secondary, required this.value, required this.onChanged, this.contentPadding});

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isDesktop) {
      return SwitchListTile(title: title, subtitle: subtitle, secondary: secondary, value: value, onChanged: onChanged, contentPadding: contentPadding);
    }
    return ListTile(
      leading: secondary,
      title: title,
      subtitle: subtitle,
      contentPadding: contentPadding,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: MacSwitch(value: value, onChanged: onChanged),
    );
  }
}
