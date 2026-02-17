import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/tyme_export_service.dart';
import '../../core/services/tyme_import_service.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../blocs/settings/settings_bloc.dart';
import '../blocs/settings/settings_event.dart';
import '../blocs/settings/settings_state.dart';
import '../blocs/timer/timer_bloc.dart';
import '../blocs/timer/timer_event.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                      ListTile(
                        leading: const Icon(Icons.work_outline),
                        title: Text(tr('settings.daily_working_hours')),
                        trailing: SizedBox(
                          width: 100,
                          child: DropdownButton<double>(
                            value: state.dailyWorkingHours,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: List.generate(17, (i) => DropdownMenuItem(value: (i + 1).toDouble(), child: Text('${i + 1}h'))),
                            onChanged: (v) {
                              if (v != null) {
                                context.read<SettingsBloc>().add(ChangeDailyWorkingHours(v));
                              }
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(tr('settings.weekly_working_days')),
                        trailing: SizedBox(
                          width: 100,
                          child: DropdownButton<int>(
                            value: state.weeklyWorkingDays,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                            onChanged: (v) {
                              if (v != null) {
                                context.read<SettingsBloc>().add(ChangeWeeklyWorkingDays(v));
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                        subtitle: const Text('JSON / CSV'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showImportDialog(context),
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
                  child: ListTile(leading: const Icon(Icons.info_outline), title: Text(tr('app_name')), subtitle: Text('${tr('settings.version')}: 1.0.0')),
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
          final importService = TymeImportService(
            timeEntryRepository: context.read<TimeEntryRepository>(),
            projectRepository: context.read<ProjectRepository>(),
            taskRepository: context.read<TaskRepository>(),
            categoryRepository: context.read<CategoryRepository>(),
          );
          ImportResult result;
          if (filePath.toLowerCase().endsWith('.csv')) {
            result = await importService.importFromCsv(filePath, mode);
          } else {
            result = await importService.importFromJson(filePath, mode);
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
                    '${result.tasksImported} tasks',
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
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: DateTime(2020),
                        lastDate: lastAllowed,
                      );
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
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json', 'csv'], dialogTitle: tr('import.select_file'));
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
