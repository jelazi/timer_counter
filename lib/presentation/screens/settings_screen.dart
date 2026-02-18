import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/backup_service.dart';
import '../../core/services/firebase_sync_service_v2.dart';
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
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('settings.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),

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
                                            ChangeWorkSchedule(weekday: weekday, start: '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}'),
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
                                            ChangeWorkSchedule(weekday: weekday, end: '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}'),
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

                // Monthly Hours Targets
                _buildMonthlyTargetsSection(context),
                const SizedBox(height: 20),

                // Format & Currency
                _buildSectionTitle(context, tr('settings.general')),
                Card(
                  child: Column(
                    children: [
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

                // Cloud Sync
                _buildSectionTitle(context, tr('sync.title')),
                _FirebaseSyncSection(settingsRepo: context.read<SettingsRepository>()),
                const SizedBox(height: 20),

                // Reminders
                _buildSectionTitle(context, tr('settings.reminders')),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.alarm),
                        title: Text(tr('settings.remind_start')),
                        value: state.remindStart,
                        onChanged: (v) {
                          context.read<SettingsBloc>().add(ToggleRemindStart(v));
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.alarm_off),
                        title: Text(tr('settings.remind_stop')),
                        value: state.remindStop,
                        onChanged: (v) {
                          context.read<SettingsBloc>().add(ToggleRemindStop(v));
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.free_breakfast),
                        title: Text(tr('settings.remind_break')),
                        value: state.remindBreak,
                        onChanged: (v) {
                          context.read<SettingsBloc>().add(ToggleRemindBreak(v));
                        },
                      ),
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
        );
      },
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
                                  context.read<FirebaseSyncService?>()?.deleteMonthlyTarget(target.id);
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
                                            context.read<FirebaseSyncService?>()?.pushMonthlyTarget(target);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(tr('monthly_targets.target_restored')), backgroundColor: Colors.green),
                                            );
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
                  context.read<FirebaseSyncService?>()?.pushMonthlyTarget(newTarget);
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
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(outputPath)],
            subject: tr('settings.backup_create'),
          ),
        );
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

// ─────────────────────────────────────────────────────────────────────────────
// Firebase Cloud Sync Section
// ─────────────────────────────────────────────────────────────────────────────

class _FirebaseSyncSection extends StatefulWidget {
  final SettingsRepository settingsRepo;

  const _FirebaseSyncSection({required this.settingsRepo});

  @override
  State<_FirebaseSyncSection> createState() => _FirebaseSyncSectionState();
}

class _FirebaseSyncSectionState extends State<_FirebaseSyncSection> {
  bool _isSyncing = false;
  String? _syncMessage;
  StreamSubscription<SyncStatus>? _statusSub;
  SyncStatus _status = SyncStatus.disabled;

  FirebaseSyncService? get _service => context.read<FirebaseSyncService?>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = _service;
      if (svc != null) {
        _status = svc.currentStatus;
        _statusSub = svc.statusStream.listen((s) {
          if (mounted) setState(() => _status = s);
        });
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  bool get _isSignedIn => _service?.isSignedIn ?? false;
  String? get _userEmail => _service?.currentUser?.email;

  Future<void> _doUpload() async {
    final svc = _service;
    if (svc == null || !svc.isSignedIn) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('sync.upload')),
        content: Text(tr('sync.confirm_upload')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('sync.upload'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runSync(() => svc.uploadAll(onProgress: _onProgress), tr('sync.upload_success'));
  }

  Future<void> _doDownload() async {
    final svc = _service;
    if (svc == null || !svc.isSignedIn) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('sync.download')),
        content: Text(tr('sync.confirm_download')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: Text(tr('sync.download')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runSync(() => svc.downloadAll(onProgress: _onProgress), tr('sync.download_success'));
  }

  void _onProgress(String message, double progress) {
    if (!mounted) return;
    setState(() => _syncMessage = message);
  }

  Future<void> _runSync(Future<SyncResult> Function() action, String successMsg) async {
    setState(() {
      _isSyncing = true;
      _syncMessage = tr('sync.syncing');
    });
    try {
      final result = await action();
      if (!mounted) return;
      if (result.hasError) {
        setState(() {
          _isSyncing = false;
          _syncMessage = '${tr('sync.sync_error')}: ${result.error}';
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('sync.sync_error')}: ${result.error}'), backgroundColor: Colors.red));
      } else {
        widget.settingsRepo.setFirebaseLastSync(DateTime.now().toIso8601String());
        setState(() {
          _isSyncing = false;
          _syncMessage = '$successMsg (${tr('sync.items_synced')}: ${result.total})';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$successMsg — '
              '${tr('sync.categories')}: ${result.categoriesSynced}, '
              '${tr('sync.projects')}: ${result.projectsSynced}, '
              '${tr('sync.tasks')}: ${result.tasksSynced}, '
              '${tr('sync.time_entries')}: ${result.timeEntriesSynced}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSyncing = false;
        _syncMessage = '${tr('sync.sync_error')}: $e';
      });
    }
  }

  String _formatLastSync() {
    final raw = widget.settingsRepo.getFirebaseLastSync();
    if (raw.isEmpty) return tr('sync.never');
    final dt = DateTime.tryParse(raw);
    if (dt == null) return tr('sync.never');
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return tr('sync.last_sync_just_now');
    if (diff.inHours < 1) return '${diff.inMinutes} min';
    if (diff.inDays < 1) return '${diff.inHours}h ${diff.inMinutes % 60}min';
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openAuthDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _FirebaseAuthDialog(syncService: _service),
    );
    if (result == true && mounted) {
      setState(() {});
      // Start listeners after successful sign in
      final svc = _service;
      if (svc != null && svc.isSignedIn) {
        svc.startListeners();
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('sync.sign_out')),
        content: Text(tr('sync.confirm_sign_out')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('sync.sign_out')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _service?.signOut();
    if (mounted) setState(() {});
  }

  Widget _buildStatusChip() {
    final IconData icon;
    final Color color;
    final String label;

    switch (_status) {
      case SyncStatus.disabled:
        icon = Icons.cloud_off;
        color = Colors.grey;
        label = tr('sync.status_disabled');
      case SyncStatus.connecting:
        icon = Icons.cloud_sync;
        color = Colors.orange;
        label = tr('sync.status_connecting');
      case SyncStatus.connected:
        icon = Icons.cloud_done;
        color = Colors.green;
        label = tr('sync.status_connected');
      case SyncStatus.error:
        icon = Icons.cloud_off;
        color = Colors.red;
        label = tr('sync.status_error');
    }

    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = _isSignedIn;

    if (_service == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListTile(
            leading: const Icon(Icons.cloud_off, color: Colors.grey),
            title: Text(tr('sync.firebase_not_available')),
            subtitle: Text(tr('sync.firebase_not_configured_hint'), style: theme.textTheme.bodySmall),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auth & Status row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(signedIn ? Icons.person : Icons.person_off, color: signedIn ? Colors.green : theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(signedIn ? _userEmail ?? '' : tr('sync.not_signed_in'), overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 4),
                        _buildStatusChip(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  signedIn
                      ? TextButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout, size: 18),
                          label: Text(tr('sync.sign_out')),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                        )
                      : FilledButton.icon(onPressed: _openAuthDialog, icon: const Icon(Icons.login, size: 18), label: Text(tr('sync.sign_in'))),
                ],
              ),
            ),

            if (signedIn) ...[
              const Divider(),

              // Last sync
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text('${tr('sync.last_sync')}: ${_formatLastSync()}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Sync status message
              if (_syncMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    _syncMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(color: _syncMessage!.contains('error') || _syncMessage!.contains('Chyba') ? Colors.red : Colors.green),
                  ),
                ),

              // Progress indicator
              if (_isSyncing) const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: LinearProgressIndicator()),

              const SizedBox(height: 8),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSyncing ? null : _doUpload,
                        icon: const Icon(Icons.cloud_upload, size: 18),
                        label: Text(tr('sync.upload'), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSyncing ? null : _doDownload,
                        icon: const Icon(Icons.cloud_download, size: 18),
                        label: Text(tr('sync.download'), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Hint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(tr('sync.real_time_hint'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Firebase Auth Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _FirebaseAuthDialog extends StatefulWidget {
  final FirebaseSyncService? syncService;

  const _FirebaseAuthDialog({required this.syncService});

  @override
  State<_FirebaseAuthDialog> createState() => _FirebaseAuthDialogState();
}

class _FirebaseAuthDialogState extends State<_FirebaseAuthDialog> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final error = await widget.syncService?.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  Future<void> _signUp() async {
    if (!_validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final error = await widget.syncService?.signUp(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  bool _validate() {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _errorMessage = tr('sync.fill_all_fields'));
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('sync.firebase_auth')),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: tr('sync.email'),
                hintText: 'user@example.com',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: tr('sync.password'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !_isLoading,
              onSubmitted: (_) => _signIn(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
            if (_isLoading) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
        OutlinedButton(onPressed: _isLoading ? null : _signUp, child: Text(tr('sync.sign_up'))),
        FilledButton(onPressed: _isLoading ? null : _signIn, child: Text(tr('sync.sign_in'))),
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
