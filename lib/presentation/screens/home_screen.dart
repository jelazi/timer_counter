import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/utils/platform_utils.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  /// Desktop screens include PDF Reports; mobile omits them.
  List<Widget> get _screens => PlatformUtils.isDesktop
      ? const [TimeTrackingScreen(), TimeEntriesOverviewScreen(), ProjectsScreen(), StatisticsScreen(), PdfReportsScreen(), SettingsScreen()]
      : const [TimeTrackingScreen(), TimeEntriesOverviewScreen(), ProjectsScreen(), StatisticsScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Text('jelazi', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
                const SizedBox(height: 4),
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
  // Desktop layout: NavigationRail
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
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
  }
}
