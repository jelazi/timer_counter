import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Neutral macOS-like surface colors that have no slot in [ColorScheme].
@immutable
class MacColors extends ThemeExtension<MacColors> {
  final Color sidebar;
  final Color sidebarSelection;
  final Color content;
  final Color groupFill;
  final Color groupBorder;
  final Color controlFill;
  final Color controlBorder;
  final Color separator;
  final Color menu;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;

  const MacColors({
    required this.sidebar,
    required this.sidebarSelection,
    required this.content,
    required this.groupFill,
    required this.groupBorder,
    required this.controlFill,
    required this.controlBorder,
    required this.separator,
    required this.menu,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
  });

  static const light = MacColors(
    sidebar: Color(0xFFEBEBEA),
    sidebarSelection: Color(0x1A000000),
    content: Color(0xFFFFFFFF),
    groupFill: Color(0xFFF6F6F6),
    groupBorder: Color(0xFFE6E6E6),
    controlFill: Color(0xFFFFFFFF),
    controlBorder: Color(0xFFD2D2D2),
    separator: Color(0xFFE5E5E5),
    menu: Color(0xFFF7F7F7),
    label: Color(0xFF1D1D1F),
    secondaryLabel: Color(0xFF6E6E73),
    tertiaryLabel: Color(0xFFAEAEB2),
  );

  static const dark = MacColors(
    sidebar: Color(0xFF2A2A2B),
    sidebarSelection: Color(0x24FFFFFF),
    content: Color(0xFF1E1E1E),
    groupFill: Color(0xFF262626),
    groupBorder: Color(0xFF333333),
    controlFill: Color(0xFF2B2B2B),
    controlBorder: Color(0xFF464648),
    separator: Color(0xFF363636),
    menu: Color(0xFF2D2D2E),
    label: Color(0xFFE6E6E8),
    secondaryLabel: Color(0xFF98989D),
    tertiaryLabel: Color(0xFF636366),
  );

  static MacColors of(BuildContext context) => Theme.of(context).extension<MacColors>() ?? (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  MacColors copyWith({
    Color? sidebar,
    Color? sidebarSelection,
    Color? content,
    Color? groupFill,
    Color? groupBorder,
    Color? controlFill,
    Color? controlBorder,
    Color? separator,
    Color? menu,
    Color? label,
    Color? secondaryLabel,
    Color? tertiaryLabel,
  }) {
    return MacColors(
      sidebar: sidebar ?? this.sidebar,
      sidebarSelection: sidebarSelection ?? this.sidebarSelection,
      content: content ?? this.content,
      groupFill: groupFill ?? this.groupFill,
      groupBorder: groupBorder ?? this.groupBorder,
      controlFill: controlFill ?? this.controlFill,
      controlBorder: controlBorder ?? this.controlBorder,
      separator: separator ?? this.separator,
      menu: menu ?? this.menu,
      label: label ?? this.label,
      secondaryLabel: secondaryLabel ?? this.secondaryLabel,
      tertiaryLabel: tertiaryLabel ?? this.tertiaryLabel,
    );
  }

  @override
  MacColors lerp(ThemeExtension<MacColors>? other, double t) {
    if (other is! MacColors) return this;
    return MacColors(
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarSelection: Color.lerp(sidebarSelection, other.sidebarSelection, t)!,
      content: Color.lerp(content, other.content, t)!,
      groupFill: Color.lerp(groupFill, other.groupFill, t)!,
      groupBorder: Color.lerp(groupBorder, other.groupBorder, t)!,
      controlFill: Color.lerp(controlFill, other.controlFill, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      menu: Color.lerp(menu, other.menu, t)!,
      label: Color.lerp(label, other.label, t)!,
      secondaryLabel: Color.lerp(secondaryLabel, other.secondaryLabel, t)!,
      tertiaryLabel: Color.lerp(tertiaryLabel, other.tertiaryLabel, t)!,
    );
  }
}

/// Compact, macOS-styled theme used on every desktop platform.
class DesktopTheme {
  DesktopTheme._();

  static const Color accentLight = Color(0xFF5856D6);
  static const Color accentDark = Color(0xFF6E6CF0);

  static const double controlHeight = 28;
  static const double toolbarHeight = 52;
  static const BorderRadius controlRadius = BorderRadius.all(Radius.circular(6));

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final mac = isDark ? MacColors.dark : MacColors.light;
    final accent = isDark ? accentDark : accentLight;

    final seeded = ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
    final scheme = seeded.copyWith(
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: Color.alphaBlend(accent.withValues(alpha: isDark ? 0.28 : 0.14), mac.content),
      onPrimaryContainer: isDark ? const Color(0xFFD9D8FF) : const Color(0xFF2E2C8F),
      secondary: mac.secondaryLabel,
      onSecondary: Colors.white,
      secondaryContainer: isDark ? const Color(0xFF48484A) : const Color(0xFFE8E8E8),
      onSecondaryContainer: mac.label,
      surface: mac.content,
      onSurface: mac.label,
      onSurfaceVariant: mac.secondaryLabel,
      surfaceContainerLowest: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
      surfaceContainerLow: isDark ? const Color(0xFF222222) : const Color(0xFFF8F8F8),
      surfaceContainer: isDark ? const Color(0xFF282828) : const Color(0xFFF3F3F3),
      surfaceContainerHigh: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEDEDED),
      surfaceContainerHighest: isDark ? const Color(0xFF353535) : const Color(0xFFE7E7E7),
      outline: mac.controlBorder,
      outlineVariant: mac.separator,
      surfaceTint: Colors.transparent,
      error: isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30),
    );

    final textTheme = _textTheme(brightness, mac);
    const shrink = MaterialTapTargetSize.shrinkWrap;
    const compact = VisualDensity(horizontal: -2, vertical: -2);
    const radius = RoundedRectangleBorder(borderRadius: controlRadius);
    final buttonText = textTheme.labelLarge!.copyWith(fontSize: 13, fontWeight: FontWeight.w500);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: controlRadius,
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      visualDensity: compact,
      materialTapTargetSize: shrink,
      splashFactory: NoSplash.splashFactory,
      scaffoldBackgroundColor: mac.content,
      canvasColor: mac.menu,
      cardColor: mac.groupFill,
      dividerColor: mac.separator,
      hoverColor: mac.label.withValues(alpha: 0.05),
      highlightColor: mac.label.withValues(alpha: 0.08),
      focusColor: accent.withValues(alpha: 0.25),
      iconTheme: IconThemeData(size: 18, color: mac.secondaryLabel),
      extensions: [mac],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: toolbarHeight,
        centerTitle: false,
        titleSpacing: 12,
        backgroundColor: mac.content,
        foregroundColor: mac.label,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(size: 18, color: mac.secondaryLabel),
        actionsIconTheme: IconThemeData(size: 18, color: mac.secondaryLabel),
        titleTextStyle: textTheme.titleLarge,
        shape: Border(bottom: BorderSide(color: mac.separator)),
      ),
      actionIconTheme: ActionIconThemeData(backButtonIconBuilder: (_) => const Icon(Icons.chevron_left, size: 22)),
      cardTheme: CardThemeData(
        elevation: 0,
        color: mac.groupFill,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: mac.groupBorder),
        ),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        visualDensity: compact,
        minTileHeight: 36,
        minVerticalPadding: 6,
        minLeadingWidth: 18,
        horizontalTitleGap: 10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        iconColor: mac.secondaryLabel,
        titleTextStyle: textTheme.bodyMedium,
        subtitleTextStyle: textTheme.bodySmall!.copyWith(color: mac.secondaryLabel),
        leadingAndTrailingTextStyle: textTheme.bodyMedium!.copyWith(color: mac.secondaryLabel),
        shape: radius,
      ),
      dividerTheme: DividerThemeData(color: mac.separator, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, controlHeight)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          shape: const WidgetStatePropertyAll(radius),
          textStyle: WidgetStatePropertyAll(buttonText),
          iconSize: const WidgetStatePropertyAll(15),
          visualDensity: compact,
          tapTargetSize: shrink,
          elevation: const WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, controlHeight)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
          shape: const WidgetStatePropertyAll(radius),
          textStyle: WidgetStatePropertyAll(buttonText),
          iconSize: const WidgetStatePropertyAll(15),
          visualDensity: compact,
          tapTargetSize: shrink,
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? mac.controlFill.withValues(alpha: 0.5) : (isDark ? const Color(0xFF3A3A3C) : mac.controlFill),
          ),
          foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? mac.tertiaryLabel : mac.label),
          side: WidgetStatePropertyAll(BorderSide(color: mac.controlBorder)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, controlHeight)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
          shape: const WidgetStatePropertyAll(radius),
          textStyle: WidgetStatePropertyAll(buttonText),
          iconSize: const WidgetStatePropertyAll(15),
          visualDensity: compact,
          tapTargetSize: shrink,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(controlHeight, controlHeight)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(5)),
          iconSize: const WidgetStatePropertyAll(17),
          shape: const WidgetStatePropertyAll(radius),
          visualDensity: compact,
          tapTargetSize: shrink,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 26)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
          shape: const WidgetStatePropertyAll(radius),
          textStyle: WidgetStatePropertyAll(buttonText.copyWith(fontSize: 12)),
          iconSize: const WidgetStatePropertyAll(14),
          visualDensity: compact,
          tapTargetSize: shrink,
          side: WidgetStatePropertyAll(BorderSide(color: mac.controlBorder)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? (isDark ? const Color(0xFF5A5A5E) : Colors.white) : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9E9)),
          ),
          foregroundColor: WidgetStatePropertyAll(mac.label),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: mac.controlFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        border: inputBorder(mac.controlBorder),
        enabledBorder: inputBorder(mac.controlBorder),
        disabledBorder: inputBorder(mac.separator),
        focusedBorder: inputBorder(accent.withValues(alpha: 0.75), 2),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 2),
        labelStyle: textTheme.bodyMedium!.copyWith(color: mac.secondaryLabel),
        floatingLabelStyle: textTheme.bodySmall!.copyWith(color: mac.secondaryLabel),
        hintStyle: textTheme.bodyMedium!.copyWith(color: mac.tertiaryLabel),
        helperStyle: textTheme.bodySmall!.copyWith(color: mac.secondaryLabel),
        errorStyle: textTheme.bodySmall!.copyWith(color: scheme.error),
        prefixIconColor: mac.secondaryLabel,
        suffixIconColor: mac.secondaryLabel,
        prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 26),
        suffixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 26),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(mac.menu),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: mac.groupBorder),
            ),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(5)),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(mac.menu),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: mac.groupBorder),
            ),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(5)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: mac.menu,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        textStyle: textTheme.bodyMedium,
        labelTextStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
        menuPadding: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: mac.groupBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: mac.controlFill,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: mac.controlBorder),
        shape: radius,
        labelStyle: textTheme.bodySmall!.copyWith(fontSize: 12, color: mac.label),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        iconTheme: IconThemeData(size: 14, color: mac.secondaryLabel),
        showCheckmark: false,
      ),
      checkboxTheme: CheckboxThemeData(
        visualDensity: compact,
        materialTapTargetSize: shrink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: mac.controlBorder, width: 1.2),
      ),
      radioTheme: const RadioThemeData(visualDensity: compact, materialTapTargetSize: shrink),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: shrink,
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? accent : mac.controlBorder),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF6F6F6),
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: mac.groupBorder),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF6F6F6),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 600),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        verticalOffset: 16,
        textStyle: textTheme.bodySmall!.copyWith(color: mac.label),
        decoration: BoxDecoration(
          color: mac.menu,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: mac.groupBorder),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.bodyMedium,
        labelColor: mac.label,
        unselectedLabelColor: mac.secondaryLabel,
        indicatorColor: accent,
        dividerColor: mac.separator,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(7),
        radius: const Radius.circular(4),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
        thumbColor: WidgetStatePropertyAll(mac.label.withValues(alpha: 0.3)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        width: 460,
        backgroundColor: isDark ? const Color(0xFF3A3A3C) : const Color(0xFF323232),
        contentTextStyle: textTheme.bodyMedium!.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: accent, foregroundColor: Colors.white),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent, linearTrackColor: mac.separator, circularTrackColor: mac.separator),
    );
  }

  /// macOS type scale: 13 pt body, 11 pt captions, no Material letter spacing.
  static TextTheme _textTheme(Brightness brightness, MacColors mac) {
    final typography = Typography.material2021(platform: defaultTargetPlatform);
    final base = brightness == Brightness.dark ? typography.white : typography.black;

    TextStyle style(TextStyle? s, double size, FontWeight weight, Color color) =>
        (s ?? const TextStyle()).copyWith(fontSize: size, fontWeight: weight, letterSpacing: 0, height: 1.25, color: color);

    return base.copyWith(
      displayLarge: style(base.displayLarge, 34, FontWeight.w700, mac.label),
      displayMedium: style(base.displayMedium, 28, FontWeight.w700, mac.label),
      displaySmall: style(base.displaySmall, 24, FontWeight.w700, mac.label),
      headlineLarge: style(base.headlineLarge, 22, FontWeight.w700, mac.label),
      headlineMedium: style(base.headlineMedium, 20, FontWeight.w700, mac.label),
      headlineSmall: style(base.headlineSmall, 17, FontWeight.w600, mac.label),
      titleLarge: style(base.titleLarge, 15, FontWeight.w600, mac.label),
      titleMedium: style(base.titleMedium, 13, FontWeight.w500, mac.label),
      titleSmall: style(base.titleSmall, 12, FontWeight.w500, mac.label),
      bodyLarge: style(base.bodyLarge, 13, FontWeight.w400, mac.label),
      bodyMedium: style(base.bodyMedium, 13, FontWeight.w400, mac.label),
      bodySmall: style(base.bodySmall, 11, FontWeight.w400, mac.secondaryLabel),
      labelLarge: style(base.labelLarge, 13, FontWeight.w500, mac.label),
      labelMedium: style(base.labelMedium, 12, FontWeight.w500, mac.label),
      labelSmall: style(base.labelSmall, 11, FontWeight.w500, mac.secondaryLabel),
    );
  }
}
