import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/tray_display_settings.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import 'app_switch_tile.dart';

/// Which parts of the menu bar title and the tray menu this device shows.
class TrayDisplaySettingsSection extends StatelessWidget {
  const TrayDisplaySettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (previous, current) => previous.trayDisplay != current.trayDisplay,
      builder: (context, state) {
        final d = state.trayDisplay;
        void update(TrayDisplaySettings next) => context.read<SettingsBloc>().add(ChangeTrayDisplay(next));

        final title = <(String, bool, TrayDisplaySettings Function(bool))>[
          ('tray.title_pomodoro_icon', d.titlePomodoroIcon, (v) => d.copyWith(titlePomodoroIcon: v)),
          ('tray.title_pomodoro_countdown', d.titlePomodoroCountdown, (v) => d.copyWith(titlePomodoroCountdown: v)),
          ('tray.title_pomodoro_round', d.titlePomodoroRound, (v) => d.copyWith(titlePomodoroRound: v)),
          ('tray.title_task_name', d.titleTaskName, (v) => d.copyWith(titleTaskName: v)),
          ('tray.title_timer_elapsed', d.titleTimerElapsed, (v) => d.copyWith(titleTimerElapsed: v)),
          ('tray.title_today_total', d.titleTodayTotal, (v) => d.copyWith(titleTodayTotal: v)),
        ];
        final menu = <(String, bool, TrayDisplaySettings Function(bool))>[
          ('tray.menu_pomodoro', d.menuPomodoro, (v) => d.copyWith(menuPomodoro: v)),
          ('tray.menu_pomodoro_with_timer', d.menuPomodoroWithTimer, (v) => d.copyWith(menuPomodoroWithTimer: v)),
          ('tray.menu_running_timers', d.menuRunningTimers, (v) => d.copyWith(menuRunningTimers: v)),
          ('tray.menu_recent_tasks', d.menuRecentTasks, (v) => d.copyWith(menuRecentTasks: v)),
          ('tray.menu_start_timer', d.menuStartTimer, (v) => d.copyWith(menuStartTimer: v)),
        ];

        Widget group(String header, List<(String, bool, TrayDisplaySettings Function(bool))> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(header, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            ),
            for (final (key, value, change) in items) AppSwitchTile(key: ValueKey(key), title: Text(tr(key)), value: value, onChanged: (v) => update(change(v))),
          ],
        );

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              group(tr('tray.title_header'), title),
              const Divider(height: 1),
              group(tr('tray.menu_header'), menu),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  tr('tray.device_only_note'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
