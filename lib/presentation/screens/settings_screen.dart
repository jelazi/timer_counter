import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/backup_service.dart';
import '../../core/services/firebase_sync_service.dart';
import '../../core/services/tyme_data_import_service.dart';
import '../../core/services/tyme_export_service.dart';
import '../../core/services/tyme_import_service.dart';
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
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                                    SizedBox(
                                      width: 80,
                                      child: Text(dayNames[i], style: TextStyle(color: schedule.enabled ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                                    ),
                                    const SizedBox(width: 8),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                    const SizedBox(width: 12),
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
                                if (context.mounted) setState(() {});
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
      final result = await FilePicker.platform.saveFile(dialogTitle: tr('settings.backup_create'), fileName: filename, type: FileType.custom, allowedExtensions: ['json']);
      if (result == null || !context.mounted) return;

      final outputPath = result.endsWith('.json') ? result : '$result.json';

      final backupService = BackupService(
        timeEntryRepository: context.read<TimeEntryRepository>(),
        projectRepository: context.read<ProjectRepository>(),
        taskRepository: context.read<TaskRepository>(),
        categoryRepository: context.read<CategoryRepository>(),
        settingsRepository: context.read<SettingsRepository>(),
        runningTimerRepository: context.read<RunningTimerRepository>(),
      );

      final path = await backupService.exportBackup(outputPath: outputPath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('common.success')}: $path'), duration: const Duration(seconds: 5)));
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
            if (context.mounted) {
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
            final result = await FilePicker.platform.saveFile(dialogTitle: tr('export.title'), fileName: filename, type: FileType.custom, allowedExtensions: [ext]);
            if (result != null) {
              final outputPath = result.endsWith('.$ext') ? result : '$result.$ext';
              final endOfDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
              if (context.mounted) Navigator.pop(context);
              widget.onExport(outputPath, _startDate, endOfDay, _selectedFormat);
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
            _buildModeOption(ImportMode.merge, tr('import.merge'), tr('import.merge_desc'), Icons.merge),
            _buildModeOption(ImportMode.append, tr('import.append'), tr('import.append_desc'), Icons.add_circle_outline),
            _buildModeOption(ImportMode.overwrite, tr('import.overwrite'), tr('import.overwrite_desc'), Icons.warning_amber),
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
      groupValue: _selectedMode,
      onChanged: (v) => setState(() => _selectedMode = v!),
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

  bool get _isConfigured => widget.settingsRepo.isFirebaseConfigured;

  FirebaseSyncService _createService() {
    return FirebaseSyncService(
      projectId: widget.settingsRepo.getFirebaseProjectId(),
      apiKey: widget.settingsRepo.getFirebaseApiKey(),
      projectRepo: context.read<ProjectRepository>(),
      taskRepo: context.read<TaskRepository>(),
      timeEntryRepo: context.read<TimeEntryRepository>(),
      categoryRepo: context.read<CategoryRepository>(),
    );
  }

  Future<void> _doUpload() async {
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
    await _runSync(() => _createService().uploadAll(onProgress: _onProgress), tr('sync.upload_success'));
  }

  Future<void> _doDownload() async {
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
    await _runSync(() => _createService().downloadAll(onProgress: _onProgress), tr('sync.download_success'));
  }

  Future<void> _doMergeSync() async {
    await _runSync(() => _createService().syncAll(onProgress: _onProgress), tr('sync.sync_success'));
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

  Future<void> _openConfig() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _FirebaseConfigDialog(settingsRepo: widget.settingsRepo),
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = _isConfigured;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Config row
            ListTile(
              leading: Icon(configured ? Icons.cloud_done : Icons.cloud_off, color: configured ? Colors.green : theme.colorScheme.onSurfaceVariant),
              title: Text(tr('sync.firebase_config')),
              subtitle: Text(
                configured ? tr('sync.configured') : tr('sync.not_configured'),
                style: TextStyle(color: configured ? Colors.green : theme.colorScheme.onSurfaceVariant),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openConfig,
            ),

            if (configured) ...[
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSyncing ? null : _doMergeSync,
                        icon: const Icon(Icons.sync, size: 18),
                        label: Text(tr('sync.sync_merge'), style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),

              // Hint
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(tr('sync.firestore_hint'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Firebase Configuration Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _FirebaseConfigDialog extends StatefulWidget {
  final SettingsRepository settingsRepo;

  const _FirebaseConfigDialog({required this.settingsRepo});

  @override
  State<_FirebaseConfigDialog> createState() => _FirebaseConfigDialogState();
}

class _FirebaseConfigDialogState extends State<_FirebaseConfigDialog> {
  late final TextEditingController _projectIdCtrl;
  late final TextEditingController _apiKeyCtrl;
  bool _testing = false;
  bool? _connectionOk;

  @override
  void initState() {
    super.initState();
    _projectIdCtrl = TextEditingController(text: widget.settingsRepo.getFirebaseProjectId());
    _apiKeyCtrl = TextEditingController(text: widget.settingsRepo.getFirebaseApiKey());
  }

  @override
  void dispose() {
    _projectIdCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (_projectIdCtrl.text.trim().isEmpty || _apiKeyCtrl.text.trim().isEmpty) return;
    setState(() {
      _testing = true;
      _connectionOk = null;
    });
    final service = FirebaseSyncService(
      projectId: _projectIdCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      projectRepo: context.read<ProjectRepository>(),
      taskRepo: context.read<TaskRepository>(),
      timeEntryRepo: context.read<TimeEntryRepository>(),
      categoryRepo: context.read<CategoryRepository>(),
    );
    final ok = await service.testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _connectionOk = ok;
    });
  }

  void _save() {
    widget.settingsRepo.setFirebaseProjectId(_projectIdCtrl.text.trim());
    widget.settingsRepo.setFirebaseApiKey(_apiKeyCtrl.text.trim());
    Navigator.pop(context, true);
  }

  void _clear() {
    widget.settingsRepo.setFirebaseProjectId('');
    widget.settingsRepo.setFirebaseApiKey('');
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('sync.firebase_config')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _projectIdCtrl,
              decoration: InputDecoration(labelText: tr('sync.project_id'), hintText: 'my-project-id', border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyCtrl,
              decoration: InputDecoration(labelText: tr('sync.api_key'), hintText: 'AIza...', border: const OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_find, size: 18),
                  label: Text(tr('sync.test_connection')),
                ),
                const SizedBox(width: 12),
                if (_connectionOk == true)
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 4),
                      Text(tr('sync.connection_ok'), style: const TextStyle(color: Colors.green)),
                    ],
                  ),
                if (_connectionOk == false)
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 4),
                      Text(tr('sync.connection_failed'), style: const TextStyle(color: Colors.red)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _clear,
          child: Text(tr('sync.clear_config'), style: const TextStyle(color: Colors.red)),
        ),
        const Spacer(),
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('common.cancel'))),
        FilledButton(onPressed: _save, child: Text(tr('common.save'))),
      ],
      actionsAlignment: MainAxisAlignment.start,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
