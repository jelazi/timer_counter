import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/pocketbase_config.dart';
import '../../core/services/pocketbase_sync_service.dart';
import '../../core/services/tyme_data_import_service.dart';
import '../../core/services/tyme_export_service.dart';
import '../../core/services/tyme_import_service.dart';
import '../../core/utils/platform_utils.dart';
import '../../data/models/monthly_hours_target_model.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/monthly_hours_target_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/running_timer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import '../blocs/timer/timer_bloc.dart';
import '../blocs/timer/timer_event.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('settings.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Appearance Section
                        _buildSectionTitle(context, tr('settings.appearance')),
                        Card(
                          child: Column(
                            children: [
                              // Theme
                              ListTile(
                                leading: const Icon(Icons.palette_outlined),
                                title: Text(tr('settings.theme')),
                                trailing: SegmentedButton<String>(
                                  segments: [
                                    ButtonSegment(value: 'light', icon: const Icon(Icons.light_mode, size: 18)),
                                    ButtonSegment(value: 'system', icon: const Icon(Icons.auto_mode, size: 18)),
                                    ButtonSegment(value: 'dark', icon: const Icon(Icons.dark_mode, size: 18)),
                                  ],
                                  selected: {state.themeMode},
                                  onSelectionChanged: (selected) {
                                    context.read<SettingsBloc>().add(ChangeThemeMode(selected.first));
                                  },
                                ),
                              ),
                              const Divider(height: 1),
                              // Language
                              ListTile(
                                leading: const Icon(Icons.language),
                                title: Text(tr('settings.language')),
                                trailing: DropdownButton<String>(
                                  value: state.language,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(value: 'en', child: Text('English')),
                                    DropdownMenuItem(value: 'cs', child: Text('Čeština')),
                                  ],
                                  onChanged: (lang) {
                                    if (lang != null) {
                                      context.read<SettingsBloc>().add(ChangeLanguage(lang));
                                      context.setLocale(Locale(lang));
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Timer Settings
                        _buildSectionTitle(context, tr('settings.timer_settings')),
                        Card(
                          child: Column(
                            children: [
                              SwitchListTile(
                                secondary: const Icon(Icons.timer),
                                title: Text(tr('settings.simultaneous_timers')),
                                value: state.simultaneousTimers,
                                onChanged: (v) {
                                  context.read<SettingsBloc>().add(ToggleSimultaneousTimers(v));
                                },
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(Icons.av_timer),
                                title: Text(tr('settings.show_seconds')),
                                value: state.showSeconds,
                                onChanged: (v) {
                                  context.read<SettingsBloc>().add(ToggleShowSeconds(v));
                                },
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(Icons.rounded_corner),
                                title: Text(tr('settings.round_time')),
                                value: state.roundTime,
                                onChanged: (v) {
                                  context.read<SettingsBloc>().add(ToggleRoundTime(v));
                                },
                              ),
                              if (state.roundTime) ...[
                                const Divider(height: 1),
                                ListTile(
                                  leading: const SizedBox(width: 24),
                                  title: Text(tr('settings.round_to')),
                                  trailing: DropdownButton<int>(
                                    value: state.roundToMinutes,
                                    underline: const SizedBox(),
                                    items: [
                                      DropdownMenuItem(value: 5, child: Text(tr('settings.minutes_5'))),
                                      DropdownMenuItem(value: 10, child: Text(tr('settings.minutes_10'))),
                                      DropdownMenuItem(value: 15, child: Text(tr('settings.minutes_15'))),
                                      DropdownMenuItem(value: 30, child: Text(tr('settings.minutes_30'))),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        context.read<SettingsBloc>().add(ChangeRoundToMinutes(v));
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Working Hours
                        _buildSectionTitle(context, tr('settings.working_hours')),
                        Card(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tr('settings.work_schedule'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                      tr('settings.work_schedule_desc'),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                                    ),
                                    const SizedBox(height: 12),
                                    ...List.generate(7, (i) {
                                      final weekday = i + 1;
                                      final dayNames = [
                                        tr('settings.monday'),
                                        tr('settings.tuesday'),
                                        tr('settings.wednesday'),
                                        tr('settings.thursday'),
                                        tr('settings.friday'),
                                        tr('settings.saturday'),
                                        tr('settings.sunday'),
                                      ];
                                      final schedule = state.workSchedule[weekday];
                                      if (schedule == null) return const SizedBox();
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 28,
                                              child: Checkbox(
                                                value: schedule.enabled,
                                                onChanged: (v) => context.read<SettingsBloc>().add(ChangeWorkSchedule(weekday: weekday, enabled: v ?? false)),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                dayNames[i],
                                                style: TextStyle(color: schedule.enabled ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            _WorkTimeButton(
                                              time: schedule.start,
                                              enabled: schedule.enabled,
                                              onTap: () async {
                                                final parts = schedule.start.split(':');
                                                final picked = await showTimePicker(
                                                  context: context,
                                                  initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                                                );
                                                if (picked != null && context.mounted) {
                                                  context.read<SettingsBloc>().add(
                                                    ChangeWorkSchedule(
                                                      weekday: weekday,
                                                      start: '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              child: Text('—', style: TextStyle(color: schedule.enabled ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                                            ),
                                            _WorkTimeButton(
                                              time: schedule.end,
                                              enabled: schedule.enabled,
                                              onTap: () async {
                                                final parts = schedule.end.split(':');
                                                final picked = await showTimePicker(
                                                  context: context,
                                                  initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
                                                );
                                                if (picked != null && context.mounted) {
                                                  context.read<SettingsBloc>().add(
                                                    ChangeWorkSchedule(
                                                      weekday: weekday,
                                                      end: '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                            const SizedBox(width: 8),
                                            if (schedule.enabled)
                                              Text(
                                                _calculateDayHours(schedule.start, schedule.end),
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Day Overrides (monthly adjustments)
                        _buildDayOverridesSection(context),
                        const SizedBox(height: 20),

                        // Monthly Hours Targets
                        _buildMonthlyTargetsSection(context),
                        const SizedBox(height: 20),

                        // PocketBase
                        _buildPocketBaseSection(context),
                        const SizedBox(height: 20),

                        // Format & Currency
                        _buildSectionTitle(context, tr('settings.general')),
                        Card(
                          child: Column(
                            children: [
                              if (isMobile)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time),
                                          const SizedBox(width: 16),
                                          Text(tr('settings.time_format'), style: Theme.of(context).textTheme.bodyLarge),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: SegmentedButton<String>(
                                          segments: [
                                            ButtonSegment(value: 'hm', label: Text(tr('settings.hours_minutes'))),
                                            ButtonSegment(value: 'decimal', label: Text(tr('settings.decimal'))),
                                          ],
                                          selected: {state.timeFormat},
                                          onSelectionChanged: (selected) {
                                            context.read<SettingsBloc>().add(ChangeTimeFormat(selected.first));
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ListTile(
                                  leading: const Icon(Icons.access_time),
                                  title: Text(tr('settings.time_format')),
                                  trailing: SegmentedButton<String>(
                                    segments: [
                                      ButtonSegment(value: 'hm', label: Text(tr('settings.hours_minutes'))),
                                      ButtonSegment(value: 'decimal', label: Text(tr('settings.decimal'))),
                                    ],
                                    selected: {state.timeFormat},
                                    onSelectionChanged: (selected) {
                                      context.read<SettingsBloc>().add(ChangeTimeFormat(selected.first));
                                    },
                                  ),
                                ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.attach_money),
                                title: Text(tr('settings.currency')),
                                trailing: DropdownButton<String>(
                                  value: state.currency,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(value: 'CZK', child: Text('CZK')),
                                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                                    DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) {
                                      context.read<SettingsBloc>().add(ChangeCurrency(v));
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // System Settings
                        _buildSectionTitle(context, 'System'),
                        Card(
                          child: Column(
                            children: [
                              SwitchListTile(
                                secondary: const Icon(Icons.launch),
                                title: Text(tr('settings.launch_at_startup')),
                                value: state.launchAtStartup,
                                onChanged: (v) {
                                  context.read<SettingsBloc>().add(ToggleLaunchAtStartup(v));
                                },
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(Icons.minimize),
                                title: Text(tr('settings.minimize_to_tray')),
                                value: state.minimizeToTray,
                                onChanged: (v) {
                                  context.read<SettingsBloc>().add(ToggleMinimizeToTray(v));
                                },
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(Icons.layers),
                                title: Text(tr('settings.allow_overlap_times')),
                                subtitle: Text(tr('settings.allow_overlap_times_desc')),
                                value: state.allowOverlapTimes,
                                onChanged: (v) {
                                  context.read<SettingsBloc>().add(ToggleAllowOverlapTimes(v));
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Data Export & Import
                        _buildSectionTitle(context, tr('settings.data')),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.file_download_outlined),
                                title: Text(tr('settings.export_data')),
                                subtitle: const Text('JSON / CSV'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _exportData(context),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.file_upload_outlined),
                                title: Text(tr('settings.import_data')),
                                subtitle: const Text('JSON / CSV / Tyme .data'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _showImportDialog(context),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Backup & Restore
                        _buildSectionTitle(context, tr('settings.backup_restore')),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.backup_outlined),
                                title: Text(tr('settings.backup_create')),
                                subtitle: Text(tr('settings.backup_create_desc')),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _createBackup(context),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.restore),
                                title: Text(tr('settings.backup_restore_action')),
                                subtitle: Text(tr('settings.backup_restore_desc')),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _restoreBackup(context),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                                title: Text(tr('settings.delete_all_data'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                                subtitle: Text(tr('settings.delete_all_data_desc')),
                                trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.error),
                                onTap: () => _deleteAllData(context),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Reminders
                        _buildSectionTitle(context, tr('settings.reminders')),
                        Card(
                          child: Column(
                            children: [
                              // ── Remind Start ──
                              SwitchListTile(
                                secondary: const Icon(Icons.alarm),
                                title: Text(tr('settings.remind_start')),
                                subtitle: Text(tr('settings.remind_start_desc')),
                                value: state.remindStart,
                                onChanged: (v) {
                                  context.read<SettingsBloc>().add(ToggleRemindStart(v));
                                },
                              ),
                              if (state.remindStart) ...[
                                _buildReminderOptions(
                                  context,
                                  intervalValue: state.remindStartInterval,
                                  urgencyValue: state.remindStartUrgency,
                                  onIntervalChanged: (v) => context.read<SettingsBloc>().add(ChangeRemindStartInterval(v)),
                                  onUrgencyChanged: (v) => context.read<SettingsBloc>().add(ChangeRemindStartUrgency(v)),
                                ),
                              ],
                              const Divider(height: 1),
                              // ── Remind Stop ──
                              SwitchListTile(
                                secondary: const Icon(Icons.alarm_off),
                                title: Text(tr('settings.remind_stop')),
                                subtitle: Text(tr('settings.remind_stop_desc')),
                                value: state.remindStop,
                                onChanged: (v) {
                                  context.read<SettingsBloc>().add(ToggleRemindStop(v));
                                },
                              ),
                              if (state.remindStop) ...[
                                _buildReminderOptions(
                                  context,
                                  intervalValue: state.remindStopInterval,
                                  urgencyValue: state.remindStopUrgency,
                                  onIntervalChanged: (v) => context.read<SettingsBloc>().add(ChangeRemindStopInterval(v)),
                                  onUrgencyChanged: (v) => context.read<SettingsBloc>().add(ChangeRemindStopUrgency(v)),
                                ),
                              ],
                              const Divider(height: 1),
                              // ── Remind Break ──
                              SwitchListTile(
                                secondary: const Icon(Icons.free_breakfast),
                                title: Text(tr('settings.remind_break')),
                                subtitle: Text(tr('settings.remind_break_desc')),
                                value: state.remindBreak,
                                onChanged: (v) {
                                  context.read<SettingsBloc>().add(ToggleRemindBreak(v));
                                },
                              ),
                              if (state.remindBreak) ...[
                                _buildReminderOptions(
                                  context,
                                  intervalValue: state.remindBreakInterval,
                                  urgencyValue: state.remindBreakUrgency,
                                  onIntervalChanged: (v) => context.read<SettingsBloc>().add(ChangeRemindBreakInterval(v)),
                                  onUrgencyChanged: (v) => context.read<SettingsBloc>().add(ChangeRemindBreakUrgency(v)),
                                  showBreakAfter: true,
                                  breakAfterValue: state.remindBreakAfter,
                                  onBreakAfterChanged: (v) => context.read<SettingsBloc>().add(ChangeRemindBreakAfter(v)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // About
                        _buildSectionTitle(context, tr('settings.about')),
                        Card(
                          child: FutureBuilder<PackageInfo>(
                            future: PackageInfo.fromPlatform(),
                            builder: (context, snapshot) {
                              final version = snapshot.hasData ? snapshot.data!.version : '...';
                              final buildNumber = snapshot.hasData ? snapshot.data!.buildNumber : '';
                              return ListTile(
                                leading: const Icon(Icons.info_outline),
                                title: Text(tr('app_name')),
                                subtitle: Text('${tr('settings.version')}: $version${buildNumber.isNotEmpty ? '+$buildNumber' : ''}'),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReminderOptions(
    BuildContext context, {
    required int intervalValue,
    required int urgencyValue,
    required ValueChanged<int> onIntervalChanged,
    required ValueChanged<int> onUrgencyChanged,
    bool showBreakAfter = false,
    int breakAfterValue = 90,
    ValueChanged<int>? onBreakAfterChanged,
  }) {
    final urgencyLabels = {
      1: (icon: Icons.notifications_none, label: tr('settings.urgency_gentle'), color: Colors.green),
      2: (icon: Icons.notifications_active, label: tr('settings.urgency_normal'), color: Colors.orange),
      3: (icon: Icons.notification_important, label: tr('settings.urgency_firm'), color: Colors.red),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Interval
          Row(
            children: [
              Text(tr('settings.reminder_interval'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: AppConstants.reminderIntervalOptions.contains(intervalValue) ? intervalValue : AppConstants.defaultReminderInterval,
                isDense: true,
                underline: const SizedBox(),
                items: AppConstants.reminderIntervalOptions.map((m) {
                  return DropdownMenuItem(value: m, child: Text('$m ${tr("settings.minutes_short")}'));
                }).toList(),
                onChanged: (v) {
                  if (v != null) onIntervalChanged(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Urgency
          Row(
            children: [
              Text(tr('settings.urgency_level'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 8),
              ...urgencyLabels.entries.map((e) {
                final selected = e.key == urgencyValue;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    avatar: Icon(e.value.icon, size: 16, color: selected ? Colors.white : e.value.color),
                    label: Text(e.value.label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
                    selected: selected,
                    selectedColor: e.value.color,
                    onSelected: (_) => onUrgencyChanged(e.key),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }),
            ],
          ),
          // Break-after (only for break reminder)
          if (showBreakAfter && onBreakAfterChanged != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(tr('settings.break_after'), style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: AppConstants.breakAfterOptions.contains(breakAfterValue) ? breakAfterValue : AppConstants.defaultBreakAfter,
                  isDense: true,
                  underline: const SizedBox(),
                  items: AppConstants.breakAfterOptions.map((m) {
                    final h = m ~/ 60;
                    final min = m % 60;
                    final label = h > 0 ? '${h}h${min > 0 ? ' ${min}m' : ''}' : '${min}m';
                    return DropdownMenuItem(value: m, child: Text(label));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) onBreakAfterChanged(v);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayOverridesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, tr('settings.day_overrides')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _DayOverridesCalendar(settingsRepository: context.read<SettingsRepository>(), syncService: context.read<PocketBaseSyncService?>()),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildPocketBaseSection(BuildContext context) {
    return _PocketBaseSettingsSection(settingsRepository: context.read<SettingsRepository>(), syncService: context.read<PocketBaseSyncService?>());
  }

  Widget _buildMonthlyTargetsSection(BuildContext context) {
    final targetRepo = context.read<MonthlyHoursTargetRepository>();
    final projectRepo = context.read<ProjectRepository>();
    final targets = targetRepo.getAll();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, tr('monthly_targets.title')),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('monthly_targets.description'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 12),
                if (targets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        tr('monthly_targets.no_targets'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                      ),
                    ),
                  )
                else
                  ...targets.map((target) {
                    final projectNames = target.projectIds
                        .map((id) {
                          final p = projectRepo.getById(id);
                          return p?.name ?? id;
                        })
                        .join(', ');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(Icons.track_changes, color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
                      ),
                      title: Text(target.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${target.targetHours.toStringAsFixed(0)}h — $projectNames', overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _showTargetDialog(context, target: target),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text(tr('monthly_targets.delete_target')),
                                  content: Text(tr('monthly_targets.delete_confirm')),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                      child: Text(tr('common.delete')),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await targetRepo.delete(target.id);
                                if (context.mounted) {
                                  context.read<PocketBaseSyncService?>()?.deleteMonthlyTarget(target.id);
                                  setState(() {});

                                  // Show SnackBar with undo
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(tr('monthly_targets.target_deleted')),
                                      duration: const Duration(seconds: 5),
                                      action: SnackBarAction(
                                        label: tr('common.undo'),
                                        onPressed: () async {
                                          await targetRepo.add(target);
                                          if (context.mounted) {
                                            context.read<PocketBaseSyncService?>()?.pushMonthlyTarget(target);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(SnackBar(content: Text(tr('monthly_targets.target_restored')), backgroundColor: Colors.green));
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton.icon(onPressed: () => _showTargetDialog(context), icon: const Icon(Icons.add, size: 18), label: Text(tr('monthly_targets.add_target'))),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTargetDialog(BuildContext context, {MonthlyHoursTargetModel? target}) {
    final targetRepo = context.read<MonthlyHoursTargetRepository>();
    final projectRepo = context.read<ProjectRepository>();
    final allProjects = projectRepo.getActive();

    final nameController = TextEditingController(text: target?.name ?? '');
    final hoursController = TextEditingController(text: target?.targetHours.toString() ?? '');
    List<String> selectedProjectIds = List<String>.from(target?.projectIds ?? []);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(target != null ? tr('monthly_targets.edit_target') : tr('monthly_targets.add_target')),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: tr('monthly_targets.target_name')),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hoursController,
                  decoration: InputDecoration(labelText: tr('monthly_targets.target_hours'), suffixText: 'h'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Text(tr('monthly_targets.select_projects'), style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allProjects.map((project) {
                        final isSelected = selectedProjectIds.contains(project.id);
                        return FilterChip(
                          label: Text(project.name),
                          selected: isSelected,
                          selectedColor: Color(project.colorValue).withValues(alpha: 0.3),
                          avatar: CircleAvatar(backgroundColor: Color(project.colorValue), radius: 6),
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedProjectIds.add(project.id);
                              } else {
                                selectedProjectIds.remove(project.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('common.cancel'))),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final hours = double.tryParse(hoursController.text) ?? 0;
                if (name.isEmpty || hours <= 0 || selectedProjectIds.isEmpty) return;

                final newTarget = MonthlyHoursTargetModel(
                  id: target?.id ?? const Uuid().v4(),
                  name: name,
                  targetHours: hours,
                  projectIds: selectedProjectIds,
                  createdAt: target?.createdAt ?? DateTime.now(),
                );
                if (target != null) {
                  await targetRepo.update(newTarget);
                } else {
                  await targetRepo.add(newTarget);
                }
                if (context.mounted) {
                  context.read<PocketBaseSyncService?>()?.pushMonthlyTarget(newTarget);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) setState(() {});
              },
              child: Text(tr('common.save')),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateDayHours(String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final diff = endMinutes - startMinutes;
    if (diff <= 0) return '0h';
    final hours = diff ~/ 60;
    final minutes = diff % 60;
    return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
  }

  Future<void> _createBackup(BuildContext context) async {
    try {
      final filename = 'timer_counter_backup_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json';

      final backupService = BackupService(
        timeEntryRepository: context.read<TimeEntryRepository>(),
        projectRepository: context.read<ProjectRepository>(),
        taskRepository: context.read<TaskRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        settingsRepository: context.read<SettingsRepository>(),
        runningTimerRepository: context.read<RunningTimerRepository>(),
      );

      if (PlatformUtils.isMobile) {
        // On mobile, write to temp dir then share
        final tempDir = await getTemporaryDirectory();
        final outputPath = '${tempDir.path}/$filename';
        await backupService.exportBackup(outputPath: outputPath);
        await SharePlus.instance.share(ShareParams(files: [XFile(outputPath)], subject: tr('settings.backup_create')));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('common.success'))));
        }
      } else {
        // Desktop: use file picker save dialog
        final result = await FilePicker.platform.saveFile(dialogTitle: tr('settings.backup_create'), fileName: filename, type: FileType.custom, allowedExtensions: ['json']);
        if (result == null || !context.mounted) return;
        final outputPath = result.endsWith('.json') ? result : '$result.json';
        final path = await backupService.exportBackup(outputPath: outputPath);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('common.success')}: $path'), duration: const Duration(seconds: 5)));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('common.error')}: $e')));
      }
    }
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('settings.backup_restore_action')),
        content: Text(tr('settings.backup_restore_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(tr('settings.restore')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], dialogTitle: tr('settings.backup_restore_action'));
    if (result == null || result.files.single.path == null || !context.mounted) return;

    try {
      final backupService = BackupService(
        timeEntryRepository: context.read<TimeEntryRepository>(),
        projectRepository: context.read<ProjectRepository>(),
        taskRepository: context.read<TaskRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        settingsRepository: context.read<SettingsRepository>(),
        runningTimerRepository: context.read<RunningTimerRepository>(),
      );

      final restoreResult = await backupService.restoreBackup(result.files.single.path!);
      if (!context.mounted) return;

      if (restoreResult.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('common.error')}: ${restoreResult.error}'), backgroundColor: Colors.red));
      } else {
        context.read<TimerBloc>().add(const LoadRunningTimers());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${tr('settings.backup_restored')}: '
              '${restoreResult.categoriesRestored} ${tr('sync.categories')}, '
              '${restoreResult.projectsRestored} ${tr('sync.projects')}, '
              '${restoreResult.tasksRestored} ${tr('sync.tasks')}, '
              '${restoreResult.entriesRestored} ${tr('sync.time_entries')}'
              '${restoreResult.settingsRestored ? ', + ${tr("settings.title")}' : ''}',
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('common.error')}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteAllData(BuildContext context) async {
    // First confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.warning_amber, size: 48, color: Theme.of(context).colorScheme.error),
        title: Text(tr('settings.delete_all_data')),
        content: Text(tr('settings.delete_all_data_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Second confirmation
    final confirmedAgain = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('settings.delete_all_data_final')),
        content: Text(tr('settings.delete_all_data_final_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('settings.delete_all_data')),
          ),
        ],
      ),
    );
    if (confirmedAgain != true || !context.mounted) return;

    try {
      final backupService = BackupService(
        timeEntryRepository: context.read<TimeEntryRepository>(),
        projectRepository: context.read<ProjectRepository>(),
        taskRepository: context.read<TaskRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        settingsRepository: context.read<SettingsRepository>(),
        runningTimerRepository: context.read<RunningTimerRepository>(),
      );

      await backupService.deleteAllData();
      if (context.mounted) {
        context.read<TimerBloc>().add(const LoadRunningTimers());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('settings.delete_all_data_success')), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('common.error')}: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _exportData(BuildContext context) async {
    showDialog(
      context: context,
      builder: (_) => _ExportDialog(
        onExport: (outputPath, startDate, endDate, format) async {
          try {
            final exportService = TymeExportService(
              timeEntryRepository: context.read<TimeEntryRepository>(),
              projectRepository: context.read<ProjectRepository>(),
              taskRepository: context.read<TaskRepository>(),
              categoryRepository: context.read<CategoryRepository>(),
              settingsRepository: context.read<SettingsRepository>(),
            );
            String path;
            if (format == 'csv') {
              path = await exportService.exportToCsv(outputPath: outputPath, startDate: startDate, endDate: endDate);
            } else {
              path = await exportService.exportToJson(outputPath: outputPath, startDate: startDate, endDate: endDate);
            }
            if (PlatformUtils.isMobile) {
              await SharePlus.instance.share(ShareParams(files: [XFile(path)], subject: tr('export.title')));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('common.success'))));
              }
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('common.success')}: $path'), duration: const Duration(seconds: 5)));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('common.error')}: $e')));
            }
          }
        },
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ImportDialog(
        onImport: (filePath, mode) async {
          ImportResult result;

          if (filePath.toLowerCase().endsWith('.data')) {
            // Tyme native SQLite format
            final tymeDataService = TymeDataImportService(
              timeEntryRepository: context.read<TimeEntryRepository>(),
              projectRepository: context.read<ProjectRepository>(),
              taskRepository: context.read<TaskRepository>(),
              categoryRepository: context.read<CategoryRepository>(),
            );
            result = await tymeDataService.importFromTymeData(filePath, mode);
          } else {
            final importService = TymeImportService(
              timeEntryRepository: context.read<TimeEntryRepository>(),
              projectRepository: context.read<ProjectRepository>(),
              taskRepository: context.read<TaskRepository>(),
              categoryRepository: context.read<CategoryRepository>(),
            );
            if (filePath.toLowerCase().endsWith('.csv')) {
              result = await importService.importFromCsv(filePath, mode);
            } else {
              result = await importService.importFromJson(filePath, mode);
            }
          }

          if (context.mounted) {
            if (result.hasError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('import.error')}: ${result.error}'), backgroundColor: Colors.red));
            } else {
              context.read<TimerBloc>().add(const LoadRunningTimers());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${tr('import.success')}: ${result.entriesImported} entries, '
                    '${result.projectsImported} projects, '
                    '${result.tasksImported} tasks, '
                    '${result.categoriesImported} categories',
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

class _ExportDialog extends StatefulWidget {
  final Function(String outputPath, DateTime startDate, DateTime endDate, String format) onExport;

  const _ExportDialog({required this.onExport});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _selectedFormat = 'json';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
  }

  String _generateFilename() {
    final ext = _selectedFormat;
    if (_startDate.month == _endDate.month && _startDate.year == _endDate.year) {
      return 'timer_counter_${DateFormat('yyyy-MM').format(_startDate)}.$ext';
    }
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);
    return 'timer_counter_${startStr}_$endStr.$ext';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('export.title')),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format selection
            Text(tr('export.format'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'json', label: Text(tr('export.json_format'))),
                ButtonSegment(value: 'csv', label: Text(tr('export.csv_format'))),
              ],
              selected: {_selectedFormat},
              onSelectionChanged: (selected) {
                setState(() => _selectedFormat = selected.first);
              },
            ),
            const SizedBox(height: 16),
            Text(tr('export.date_range'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, size: 20),
                    title: Text(tr('export.from')),
                    subtitle: Text(DateFormat('d.M.yyyy').format(_startDate)),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, size: 20),
                    title: Text(tr('export.to')),
                    subtitle: Text(DateFormat('d.M.yyyy').format(_endDate)),
                    onTap: () async {
                      final lastAllowed = DateTime.now().add(const Duration(days: 365));
                      final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2020), lastDate: lastAllowed);
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
        FilledButton.icon(
          onPressed: () async {
            final filename = _generateFilename();
            final ext = _selectedFormat;
            final endOfDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

            if (PlatformUtils.isMobile) {
              // On mobile, write to temp dir then share
              final tempDir = await getTemporaryDirectory();
              final outputPath = '${tempDir.path}/$filename';
              if (context.mounted) Navigator.pop(context);
              widget.onExport(outputPath, _startDate, endOfDay, _selectedFormat);
            } else {
              final result = await FilePicker.platform.saveFile(dialogTitle: tr('export.title'), fileName: filename, type: FileType.custom, allowedExtensions: [ext]);
              if (result != null) {
                final outputPath = result.endsWith('.$ext') ? result : '$result.$ext';
                if (context.mounted) Navigator.pop(context);
                widget.onExport(outputPath, _startDate, endOfDay, _selectedFormat);
              }
            }
          },
          icon: const Icon(Icons.file_download),
          label: Text(tr('export.export')),
        ),
      ],
    );
  }
}

class _ImportDialog extends StatefulWidget {
  final Function(String filePath, ImportMode mode) onImport;

  const _ImportDialog({required this.onImport});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  ImportMode _selectedMode = ImportMode.merge;
  String? _selectedFilePath;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('import.title')),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File selection
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.file_open),
              title: Text(_selectedFilePath != null ? _selectedFilePath!.split('/').last : tr('import.select_file')),
              subtitle: _selectedFilePath != null ? Text(_selectedFilePath!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
              trailing: FilledButton.tonal(onPressed: _pickFile, child: Text(tr('import.select_file'))),
            ),
            const SizedBox(height: 16),
            Text(tr('import.import_mode'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            RadioGroup<ImportMode>(
              groupValue: _selectedMode,
              onChanged: (v) {
                if (v != null) setState(() => _selectedMode = v);
              },
              child: Column(
                children: [
                  _buildModeOption(ImportMode.merge, tr('import.merge'), tr('import.merge_desc'), Icons.merge),
                  _buildModeOption(ImportMode.append, tr('import.append'), tr('import.append_desc'), Icons.add_circle_outline),
                  _buildModeOption(ImportMode.overwrite, tr('import.overwrite'), tr('import.overwrite_desc'), Icons.warning_amber),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
        FilledButton.icon(onPressed: _selectedFilePath != null ? () => _doImport(context) : null, icon: const Icon(Icons.file_upload), label: Text(tr('settings.import_data'))),
      ],
    );
  }

  Widget _buildModeOption(ImportMode mode, String title, String description, IconData icon) {
    return RadioListTile<ImportMode>(
      contentPadding: EdgeInsets.zero,
      value: mode,
      title: Row(children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(title)]),
      subtitle: Text(description, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'csv', 'data'], dialogTitle: tr('import.select_file'));
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFilePath = result.files.single.path);
    }
  }

  Future<void> _doImport(BuildContext context) async {
    if (_selectedMode == ImportMode.overwrite) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('import.overwrite')),
          content: Text(tr('import.confirm_overwrite')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(tr('import.overwrite')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!context.mounted) return;
    Navigator.pop(context);
    widget.onImport(_selectedFilePath!, _selectedMode);
  }
}

class _PocketBaseSettingsSection extends StatefulWidget {
  final SettingsRepository settingsRepository;
  final PocketBaseSyncService? syncService;

  const _PocketBaseSettingsSection({required this.settingsRepository, required this.syncService});

  @override
  State<_PocketBaseSettingsSection> createState() => _PocketBaseSettingsSectionState();
}

class _PocketBaseSettingsSectionState extends State<_PocketBaseSettingsSection> {
  final _urlController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  StreamSubscription<SyncStatus>? _statusSubscription;
  SyncStatus _status = SyncStatus.disabled;
  PocketBaseConfigSource? _source;
  bool _isLoading = true;
  bool _isTesting = false;
  bool _isSaving = false;
  bool _isSyncing = false;
  bool _obscurePassword = true;
  bool? _lastTestSucceeded;
  String? _message;

  bool get _isBusy => _isLoading || _isTesting || _isSaving || _isSyncing;

  @override
  void initState() {
    super.initState();
    _status = widget.syncService?.currentStatus ?? SyncStatus.disabled;
    _statusSubscription = widget.syncService?.statusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _status = status;
      });
    });
    _loadConfig();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _urlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final effective = await PocketBaseConfig.loadEffective(widget.settingsRepository);
    if (!mounted) return;

    setState(() {
      _urlController.text = effective?.url ?? '';
      _emailController.text = effective?.email ?? '';
      _passwordController.text = effective?.password ?? '';
      _source = effective?.source;
      _isLoading = false;
      _message = _buildInitialMessage();
      _lastTestSucceeded = widget.syncService?.isSignedIn == true ? true : null;
    });
  }

  String _buildInitialMessage() {
    final syncService = widget.syncService;
    if (syncService?.isSignedIn == true) {
      final email = syncService?.userEmail;
      return email == null || email.isEmpty ? tr('sync.connection_ok') : '${tr('sync.connection_ok')}: $email';
    }
    final error = syncService?.lastError;
    if (error != null && error.isNotEmpty) {
      return '${tr('sync.connection_failed')}: $error';
    }
    if (_source == null) return tr('sync.no_effective_config');
    return tr('sync.ready_to_test');
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!PocketBaseConfig.isValid(url: url, email: email, password: password)) {
      setState(() {
        _lastTestSucceeded = false;
        _message = tr('sync.invalid_config');
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _message = tr('sync.testing_connection');
    });

    final result = await PocketBaseConfig.testConnection(url: url, email: email, password: password);
    if (!mounted) return;

    setState(() {
      _isTesting = false;
      _lastTestSucceeded = result.isSuccess;
      _message = result.isSuccess ? '${tr('sync.connection_ok')}: ${result.message}' : '${tr('sync.connection_failed')}: ${result.message}';
    });
  }

  Future<void> _saveOverride() async {
    final url = _urlController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (!PocketBaseConfig.isValid(url: url, email: email, password: password)) {
      setState(() {
        _lastTestSucceeded = false;
        _message = tr('sync.invalid_config');
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _message = tr('sync.saving_override');
    });

    await widget.settingsRepository.setPocketBaseUrl(url);
    await widget.settingsRepository.setPocketBaseEmail(email);
    await widget.settingsRepository.setPocketBasePassword(password);
    await widget.settingsRepository.setPocketBaseEnabled(true);

    final applyError = await _applyConfigToRunningService(PocketBaseConfig(url: url, email: email, password: password, source: PocketBaseConfigSource.settingsOverride));

    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _source = PocketBaseConfigSource.settingsOverride;
      if (applyError == null) {
        _lastTestSucceeded = true;
        _message = widget.syncService == null ? tr('sync.override_saved_restart_required') : tr('sync.override_saved_connected');
      } else {
        _lastTestSucceeded = false;
        _message = '${tr('sync.override_saved')}: $applyError';
      }
    });
  }

  Future<void> _clearOverride() async {
    setState(() {
      _isSaving = true;
      _message = tr('sync.loading_file_defaults');
    });

    await widget.settingsRepository.clearPocketBaseOverride();

    final bundled = await PocketBaseConfig.loadBundled();
    await widget.settingsRepository.setPocketBaseEnabled(bundled != null);
    final applyError = bundled == null ? await _disconnectRunningService() : await _applyConfigToRunningService(bundled);

    if (!mounted) return;

    await _loadConfig();
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      if (bundled == null) {
        _lastTestSucceeded = null;
        _message = tr('sync.no_effective_config');
      } else if (applyError == null) {
        _lastTestSucceeded = true;
        _message = widget.syncService == null ? tr('sync.file_default_restart_required') : tr('sync.file_default_applied');
      } else {
        _lastTestSucceeded = false;
        _message = '${tr('sync.connection_failed')}: $applyError';
      }
    });
  }

  Future<String?> _applyConfigToRunningService(PocketBaseConfig config) async {
    final syncService = widget.syncService;
    if (syncService == null) return null;

    await syncService.signOut();
    syncService.updateServerUrl(config.url);
    final error = await syncService.signIn(config.email, config.password);
    if (error != null) return error;

    await syncService.startListeners();
    if (syncService.lastError != null) return syncService.lastError;

    // Run smart first sync after successful connection
    final (action, result) = await syncService.smartFirstSync(
      onProgress: (msg, _) {
        if (mounted) setState(() => _message = msg);
      },
    );
    if (action == SmartSyncAction.conflict) {
      if (mounted) await _showConflictDialog();
    } else if (result?.hasError == true) {
      return result!.error;
    }
    return null;
  }

  Future<String?> _disconnectRunningService() async {
    final syncService = widget.syncService;
    if (syncService == null) return null;
    await syncService.signOut();
    return null;
  }

  Future<void> _uploadAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('sync.upload')),
        content: Text(tr('sync.confirm_upload')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('sync.upload'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSyncing = true;
      _message = tr('sync.syncing');
    });

    final result = await widget.syncService!.uploadAll(
      onProgress: (msg, _) {
        if (mounted) setState(() => _message = msg);
      },
    );

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      if (result.hasError) {
        _lastTestSucceeded = false;
        _message = '${tr('sync.sync_error')}: ${result.error}';
      } else {
        _lastTestSucceeded = true;
        _message = '${tr('sync.upload_success')} (${result.total}${tr('sync.items_synced')})';
      }
    });
  }

  Future<void> _downloadAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('sync.download')),
        content: Text(tr('sync.confirm_download')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('sync.download'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isSyncing = true;
      _message = tr('sync.syncing');
    });

    final result = await widget.syncService!.downloadAll(
      onProgress: (msg, _) {
        if (mounted) setState(() => _message = msg);
      },
    );

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      if (result.hasError) {
        _lastTestSucceeded = false;
        _message = '${tr('sync.sync_error')}: ${result.error}';
      } else {
        _lastTestSucceeded = true;
        _message = '${tr('sync.download_success')} (${result.total}${tr('sync.items_synced')})';
      }
    });
  }

  Future<void> _showConflictDialog() async {
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tr('sync.first_sync_title')),
        content: Text(tr('sync.first_sync_conflict')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'skip'), child: Text(tr('sync.first_sync_skip'))),
          OutlinedButton.icon(onPressed: () => Navigator.pop(ctx, 'download'), icon: const Icon(Icons.cloud_download_outlined, size: 18), label: Text(tr('sync.download'))),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, 'upload'), icon: const Icon(Icons.cloud_upload_outlined, size: 18), label: Text(tr('sync.upload'))),
        ],
      ),
    );

    if (action == null || action == 'skip' || !mounted) return;

    setState(() {
      _isSyncing = true;
      _message = tr('sync.syncing');
    });

    final result = action == 'upload'
        ? await widget.syncService!.uploadAll(
            onProgress: (msg, _) {
              if (mounted) setState(() => _message = msg);
            },
          )
        : await widget.syncService!.downloadAll(
            onProgress: (msg, _) {
              if (mounted) setState(() => _message = msg);
            },
          );

    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      if (result.hasError) {
        _lastTestSucceeded = false;
        _message = '${tr('sync.sync_error')}: ${result.error}';
      } else {
        _lastTestSucceeded = true;
        _message = '${tr('sync.sync_success')} (${result.total}${tr('sync.items_synced')})';
      }
    });
  }

  String _formatLastSync() {
    final lastSync = widget.settingsRepository.getPocketBaseLastSync();
    if (lastSync.isEmpty) return tr('sync.never');
    final date = DateTime.tryParse(lastSync);
    if (date == null) return lastSync;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return tr('sync.last_sync_just_now');
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inDays < 1) return '${diff.inHours}h ${diff.inMinutes % 60}min';
    return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  ({String label, Color color, IconData icon}) _statusStyle(BuildContext context) {
    switch (_status) {
      case SyncStatus.connecting:
        return (label: tr('sync.status_connecting'), color: Colors.orange, icon: Icons.cloud_sync);
      case SyncStatus.connected:
        return (label: tr('sync.status_connected'), color: Colors.green, icon: Icons.cloud_done);
      case SyncStatus.error:
        return (label: tr('sync.status_error'), color: Colors.red, icon: Icons.cloud_off);
      case SyncStatus.disabled:
        return (label: tr('sync.status_disabled'), color: Theme.of(context).colorScheme.outline, icon: Icons.cloud_off);
    }
  }

  String _sourceLabel() {
    switch (_source) {
      case PocketBaseConfigSource.settingsOverride:
        return tr('sync.source_settings');
      case PocketBaseConfigSource.bundledAsset:
        return tr('sync.source_file');
      case null:
        return tr('sync.source_none');
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(context);
    final syncService = widget.syncService;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            tr('sync.title'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('sync.subtitle'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            '${tr('sync.current_source')}: ${_sourceLabel()}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                          ),
                          if (syncService?.userEmail case final userEmail?) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${tr('sync.active_user')}: $userEmail',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Chip(
                      avatar: Icon(style.icon, size: 18, color: style.color),
                      label: Text(style.label, style: TextStyle(color: style.color)),
                      backgroundColor: style.color.withValues(alpha: 0.1),
                      side: BorderSide(color: style.color.withValues(alpha: 0.3)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  enabled: !_isBusy,
                  decoration: InputDecoration(labelText: tr('sync.server_url'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.dns_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  enabled: !_isBusy,
                  decoration: InputDecoration(labelText: tr('sync.email'), border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  enabled: !_isBusy,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: tr('sync.password'),
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: _isBusy ? null : () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(tr('sync.override_hint'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_lastTestSucceeded == false ? Colors.red : (_lastTestSucceeded == true ? Colors.green : Theme.of(context).colorScheme.surfaceContainerHighest))
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_lastTestSucceeded == false ? Colors.red : (_lastTestSucceeded == true ? Colors.green : Theme.of(context).colorScheme.outline)).withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: Text(_message!),
                  ),
                ],
                if (_isBusy) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(onPressed: _isBusy ? null : _testConnection, icon: const Icon(Icons.network_check, size: 18), label: Text(tr('sync.test_connection'))),
                    OutlinedButton.icon(onPressed: _isBusy ? null : _saveOverride, icon: const Icon(Icons.save_outlined, size: 18), label: Text(tr('sync.save_override'))),
                    TextButton.icon(onPressed: _isBusy ? null : _clearOverride, icon: const Icon(Icons.restart_alt, size: 18), label: Text(tr('sync.use_file_default'))),
                  ],
                ),
                // ── Sync actions (only when connected) ──
                if (_status == SyncStatus.connected) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(tr('sync.sync_actions'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(tr('sync.sync_actions_hint'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(onPressed: _isBusy ? null : _uploadAll, icon: const Icon(Icons.cloud_upload_outlined, size: 18), label: Text(tr('sync.upload'))),
                      OutlinedButton.icon(onPressed: _isBusy ? null : _downloadAll, icon: const Icon(Icons.cloud_download_outlined, size: 18), label: Text(tr('sync.download'))),
                    ],
                  ),
                  if (syncService != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${tr('sync.last_sync')}: ${_formatLastSync()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DayOverridesCalendar extends StatefulWidget {
  final SettingsRepository settingsRepository;
  final PocketBaseSyncService? syncService;

  const _DayOverridesCalendar({required this.settingsRepository, required this.syncService});

  @override
  State<_DayOverridesCalendar> createState() => _DayOverridesCalendarState();
}

class _DayOverridesCalendarState extends State<_DayOverridesCalendar> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _previousMonth() {
    setState(() {
      _month--;
      if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      _month++;
      if (_month > 12) {
        _month = 1;
        _year++;
      }
    });
  }

  Future<void> _toggleDay(DateTime date) async {
    final repo = widget.settingsRepository;
    final currentOverride = repo.getDayOverride(date);
    final isNormallyWorkDay = repo.getWorkScheduleEnabled(date.weekday);
    String? newOverride;

    if (isNormallyWorkDay) {
      // Normal work day: toggle between normal → off → normal
      if (currentOverride == 'off') {
        newOverride = null;
      } else {
        newOverride = 'off';
      }
    } else {
      // Non-work day: toggle between normal → work → normal
      if (currentOverride == 'work') {
        newOverride = null;
      } else {
        newOverride = 'work';
      }
    }

    await repo.setDayOverride(date, newOverride);
    final syncService = widget.syncService;
    if (syncService != null) {
      if (newOverride == null) {
        await syncService.deleteDayOverride(date);
      } else {
        await syncService.pushDayOverride(date, newOverride);
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.settingsRepository;
    final overrides = repo.getDayOverridesForMonth(_year, _month);
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final firstWeekday = DateTime(_year, _month, 1).weekday; // 1=Mon
    final locale = context.locale.languageCode;
    final monthName = DateFormat('MMMM yyyy', locale).format(DateTime(_year, _month));

    // Count work days this month
    int workDays = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      if (repo.isWorkDay(DateTime(_year, _month, d))) workDays++;
    }

    final dayLabels = [
      tr('settings.monday').substring(0, 2),
      tr('settings.tuesday').substring(0, 2),
      tr('settings.wednesday').substring(0, 2),
      tr('settings.thursday').substring(0, 2),
      tr('settings.friday').substring(0, 2),
      tr('settings.saturday').substring(0, 2),
      tr('settings.sunday').substring(0, 2),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('settings.day_overrides_desc'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 12),
        // Month navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: _previousMonth),
            Text('${monthName[0].toUpperCase()}${monthName.substring(1)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
          ],
        ),
        const SizedBox(height: 4),
        // Work days count
        Center(
          child: Text(
            tr('settings.work_days_count', namedArgs: {'count': workDays.toString()}),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 8),
        // Day headers
        Row(
          children: dayLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        ..._buildCalendarRows(context, daysInMonth, firstWeekday, overrides),
        const SizedBox(height: 12),
        // Legend
        Text(
          tr('settings.tap_to_toggle'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _legendItem(context, Colors.green.shade100, Colors.green.shade800, tr('settings.normal_work_day')),
            _legendItem(context, Colors.red.shade100, Colors.red.shade800, tr('settings.day_off')),
            _legendItem(context, Colors.blue.shade100, Colors.blue.shade800, tr('settings.extra_work_day')),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildCalendarRows(BuildContext context, int daysInMonth, int firstWeekday, Map<DateTime, String> overrides) {
    final rows = <Widget>[];
    final cells = <Widget>[];

    // Empty cells before first day
    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const Expanded(child: SizedBox(height: 36)));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_year, _month, day);
      final override = overrides[date];
      final isEffectiveWorkDay = widget.settingsRepository.isWorkDay(date);

      Color bgColor;
      Color textColor;
      BoxBorder? border;

      if (override == 'off') {
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        border = Border.all(color: Colors.red.shade400, width: 2);
      } else if (override == 'work') {
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        border = Border.all(color: Colors.blue.shade400, width: 2);
      } else if (isEffectiveWorkDay) {
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
      } else {
        bgColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
        textColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
      }

      cells.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              _toggleDay(date);
            },
            child: Container(
              height: 36,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6), border: border),
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(fontSize: 12, fontWeight: override != null ? FontWeight.bold : FontWeight.w500, color: textColor),
                ),
              ),
            ),
          ),
        ),
      );

      if ((firstWeekday - 1 + day) % 7 == 0 || day == daysInMonth) {
        // Fill remaining cells in the last row
        if (day == daysInMonth) {
          final remaining = 7 - cells.length;
          for (int i = 0; i < remaining; i++) {
            cells.add(const Expanded(child: SizedBox(height: 36)));
          }
        }
        rows.add(Row(children: List.from(cells)));
        cells.clear();
      }
    }

    return rows;
  }

  Widget _legendItem(BuildContext context, Color bgColor, Color textColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _WorkTimeButton extends StatelessWidget {
  final String time;
  final bool enabled;
  final VoidCallback onTap;

  const _WorkTimeButton({required this.time, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: enabled ? Theme.of(context).colorScheme.outline : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          time,
          style: TextStyle(fontWeight: FontWeight.w500, color: enabled ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}
