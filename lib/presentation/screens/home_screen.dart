import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/desktop_theme.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/running_timer_model.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_state.dart';
import '../blocs/timer/timer_bloc.dart';
import '../blocs/timer/timer_state.dart';
import '../widgets/desktop/desktop_sidebar.dart';
import 'pdf_reports_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';
import 'standalone_invoices_screen.dart';
import 'statistics_screen.dart';
import 'time_entries_overview_screen.dart';
import 'time_tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  /// Desktop and web show the full navigation set; mobile omits PDF Reports and Standalone Invoices.
  List<Widget> get _screens => PlatformUtils.isMobile
      ? const [TimeTrackingScreen(), TimeEntriesOverviewScreen(), ProjectsScreen(), StatisticsScreen(), SettingsScreen()]
      : const [TimeTrackingScreen(), TimeEntriesOverviewScreen(), ProjectsScreen(), StatisticsScreen(), PdfReportsScreen(), StandaloneInvoicesScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isDesktop) HardwareKeyboard.instance.addHandler(_handleNavigationKey);
  }

  @override
  void dispose() {
    if (PlatformUtils.isDesktop) HardwareKeyboard.instance.removeHandler(_handleNavigationKey);
    super.dispose();
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.primary, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.timer, color: Colors.white, size: 32),
        ),
        title: const Text('Timer Counter'),
        content: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (ctx2, snapshot) {
            final version = snapshot.hasData ? snapshot.data!.version : '...';
            final buildNumber = snapshot.hasData ? snapshot.data!.buildNumber : '';
            final versionText = '$version${buildNumber.isNotEmpty ? '+$buildNumber' : ''}';
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tr('settings.version')}: $versionText',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 16),
                Text(tr('app_about.description'), textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.code, size: 16, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Text('Flutter + Dart', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
                const SizedBox(height: 8),
                Text('© ${DateTime.now().year}', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4))),
              ],
            );
          },
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('common.ok')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        if (PlatformUtils.isMobile) return _buildMobileLayout(context);
        return _buildDesktopLayout(context);
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Mobile layout: BottomNavigationBar
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _screens[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        height: 56,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.access_time), selectedIcon: const Icon(Icons.access_time_filled), label: tr('nav.time_tracking')),
          NavigationDestination(icon: const Icon(Icons.list_alt_outlined), selectedIcon: const Icon(Icons.list_alt), label: tr('time_entries.title')),
          NavigationDestination(icon: const Icon(Icons.folder_outlined), selectedIcon: const Icon(Icons.folder), label: tr('nav.projects')),
          NavigationDestination(icon: const Icon(Icons.bar_chart_outlined), selectedIcon: const Icon(Icons.bar_chart), label: tr('nav.statistics')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: tr('nav.settings')),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Desktop layout: macOS-style sidebar + content pane
  // ─────────────────────────────────────────────────────────────────────────

  void _select(int index) {
    if (index == _selectedIndex || index < 0 || index >= _screens.length) return;
    setState(() => _selectedIndex = index);
  }

  /// Cmd+1…Cmd+7 switch sections and Cmd+, opens Settings (Ctrl on Windows/Linux).
  /// A global handler, because the pane's focus is lost whenever its navigator is replaced.
  bool _handleNavigationKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final keyboard = HardwareKeyboard.instance;
    final modifier = defaultTargetPlatform == TargetPlatform.macOS ? keyboard.isMetaPressed : keyboard.isControlPressed;
    if (!modifier || keyboard.isShiftPressed || keyboard.isAltPressed) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.comma) {
      _select(_screens.length - 1);
      return true;
    }
    final index = key.keyId - LogicalKeyboardKey.digit1.keyId;
    if (index < 0 || index >= _screens.length || index > 8) return false;
    _select(index);
    return true;
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final isWindows = Platform.isWindows;
    final mac = MacColors.of(context);

    final shell = Row(
      children: [
        SizedBox(
          width: 220,
          child: DesktopSidebar(
            topInset: isWindows ? 12 : DesktopTheme.toolbarHeight,
            selectedIndex: _selectedIndex,
            onSelected: _select,
            items: [
              SidebarItem(icon: Icons.timer_outlined, label: tr('nav.time_tracking'), section: tr('nav.section_tracking')),
              SidebarItem(icon: Icons.list_alt, label: tr('time_entries.title'), section: tr('nav.section_tracking')),
              SidebarItem(icon: Icons.folder_outlined, label: tr('nav.projects'), section: tr('nav.section_tracking')),
              SidebarItem(icon: Icons.bar_chart, label: tr('nav.statistics'), section: tr('nav.section_reports')),
              SidebarItem(icon: Icons.picture_as_pdf_outlined, label: tr('nav.pdf_reports'), section: tr('nav.section_reports')),
              SidebarItem(icon: Icons.receipt_long_outlined, label: tr('nav.standalone_invoices'), section: tr('nav.section_reports')),
            ],
            bottomItems: [SidebarItem(icon: Icons.settings_outlined, label: tr('nav.settings'))],
            footer: _SidebarTimerStatus(onTap: () => _select(0), onAbout: () => _showAboutDialog(context)),
          ),
        ),
        VerticalDivider(width: 1, thickness: 1, color: mac.separator),
        Expanded(
          child: ClipRect(
            child: Navigator(
              key: ValueKey(_selectedIndex),
              onGenerateRoute: (settings) => PageRouteBuilder(settings: settings, transitionDuration: Duration.zero, pageBuilder: (_, _, _) => _screens[_selectedIndex]),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: mac.content,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: isWindows ? kWindowCaptionHeight : 0),
            child: shell,
          ),
          if (isWindows)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Constrain the height — without it WindowCaption's inner
              // `height: double.infinity` expands to fill the whole window and
              // its DragToMoveArea swallows every click.
              height: kWindowCaptionHeight,
              child: WindowCaption(brightness: Theme.of(context).brightness, title: const SizedBox()),
            ),
        ],
      ),
    );
  }
}

/// Sidebar footer: the running timer (if any) and the app name / About entry.
class _SidebarTimerStatus extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onAbout;

  const _SidebarTimerStatus({required this.onTap, required this.onAbout});

  @override
  Widget build(BuildContext context) {
    final mac = MacColors.of(context);
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<TimerBloc, TimerState>(
      builder: (context, timerState) {
        final running = timerState is TimerRunning ? timerState.runningTimers : const <RunningTimerModel>[];
        final showSeconds = context.select<SettingsBloc, bool>((b) => b.state.showSeconds);

        Widget? timerCard;
        if (running.isNotEmpty) {
          final timer = running.first;
          final project = context.read<ProjectRepository>().getById(timer.projectId);
          final task = context.read<TaskRepository>().getById(timer.taskId);
          timerCard = GestureDetector(
            onTap: onTap,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: mac.content.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: mac.groupBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: project != null ? Color(project.colorValue) : mac.tertiaryLabel, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task?.name ?? '—',
                            style: textTheme.bodySmall?.copyWith(color: mac.label, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(project?.name ?? '', style: textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      TimeFormatter.formatDuration(timer.elapsedSeconds, showSeconds: showSeconds),
                      style: textTheme.bodySmall?.copyWith(color: mac.label, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?timerCard,
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAbout,
                style: TextButton.styleFrom(foregroundColor: mac.secondaryLabel, minimumSize: const Size(0, 24), padding: const EdgeInsets.symmetric(horizontal: 8)),
                icon: const Icon(Icons.timer, size: 14),
                label: Text('Timer Counter', style: textTheme.bodySmall),
              ),
            ),
          ],
        );
      },
    );
  }
}
