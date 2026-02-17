import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/services/dock_service.dart';
import '../../data/repositories/settings_repository.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_state.dart';
import 'pdf_reports_screen.dart';
import 'projects_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'time_entries_overview_screen.dart';
import 'time_tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [TimeTrackingScreen(), TimeEntriesOverviewScreen(), ProjectsScreen(), StatisticsScreen(), PdfReportsScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // setPreventClose(true) is already called in main.dart before window is shown
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Always hide to tray on close — only tray Quit actually exits
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
      await DockService.hideFromDock();
    }
  }

  @override
  void onWindowMinimize() async {
    final settingsRepo = context.read<SettingsRepository>();
    final minimizeToTray = settingsRepo.getMinimizeToTray();
    if (minimizeToTray) {
      await windowManager.hide();
      await DockService.hideFromDock();
    }
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${tr('settings.version')}: 1.0.0', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7))),
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
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, size: 16, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Text('Lubomír Žižka', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
            const SizedBox(height: 4),
            Text('© ${DateTime.now().year}', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4))),
          ],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('common.ok')))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  extended: MediaQuery.of(context).size.width > 1200,
                  minExtendedWidth: 200,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => _showAboutDialog(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.timer, color: Colors.white, size: 24),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Timer', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: Tooltip(message: tr('nav.time_tracking'), child: const Icon(Icons.access_time)),
                      selectedIcon: Tooltip(message: tr('nav.time_tracking'), child: const Icon(Icons.access_time_filled)),
                      label: Text(tr('nav.time_tracking')),
                    ),
                    NavigationRailDestination(
                      icon: Tooltip(message: tr('time_entries.title'), child: const Icon(Icons.list_alt_outlined)),
                      selectedIcon: Tooltip(message: tr('time_entries.title'), child: const Icon(Icons.list_alt)),
                      label: Text(tr('time_entries.title')),
                    ),
                    NavigationRailDestination(
                      icon: Tooltip(message: tr('nav.projects'), child: const Icon(Icons.folder_outlined)),
                      selectedIcon: Tooltip(message: tr('nav.projects'), child: const Icon(Icons.folder)),
                      label: Text(tr('nav.projects')),
                    ),
                    NavigationRailDestination(
                      icon: Tooltip(message: tr('nav.statistics'), child: const Icon(Icons.bar_chart_outlined)),
                      selectedIcon: Tooltip(message: tr('nav.statistics'), child: const Icon(Icons.bar_chart)),
                      label: Text(tr('nav.statistics')),
                    ),
                    NavigationRailDestination(
                      icon: Tooltip(message: tr('nav.pdf_reports'), child: const Icon(Icons.picture_as_pdf_outlined)),
                      selectedIcon: Tooltip(message: tr('nav.pdf_reports'), child: const Icon(Icons.picture_as_pdf)),
                      label: Text(tr('nav.pdf_reports')),
                    ),
                    NavigationRailDestination(
                      icon: Tooltip(message: tr('nav.settings'), child: const Icon(Icons.settings_outlined)),
                      selectedIcon: Tooltip(message: tr('nav.settings'), child: const Icon(Icons.settings)),
                      label: Text(tr('nav.settings')),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        );
      },
    );
  }
}
