import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/pocketbase_sync_service.dart';
import '../../data/models/monthly_hours_target_model.dart';
import '../../data/models/work_day_schedule.dart';
import '../../data/repositories/monthly_hours_target_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../widgets/day_overrides_calendar.dart';

/// Schedule, days off and month goals of a single work context.
///
/// A context that defines none of this simply follows the global settings, so
/// everything here is an opt-in override.
class WorkContextScreen extends StatefulWidget {
  final MonthlyHoursTargetModel target;

  const WorkContextScreen({super.key, required this.target});

  @override
  State<WorkContextScreen> createState() => _WorkContextScreenState();
}

class _WorkContextScreenState extends State<WorkContextScreen> {
  late MonthlyHoursTargetModel _target;

  @override
  void initState() {
    super.initState();
    _target = widget.target;
  }

  SettingsRepository get _settings => context.read<SettingsRepository>();

  PocketBaseSyncService? get _sync => context.read<PocketBaseSyncService?>();

  Future<void> _pushContextSettings() async {
    await _sync?.pushContextSettings(_target.id);
  }

  Future<void> _setUsesOwnSchedule(bool value) async {
    await _settings.setContextUsesOwnSchedule(_target.id, value);
    await _pushContextSettings();
    if (mounted) setState(() {});
  }

  Future<void> _pickTime(int weekday, WorkDaySchedule schedule, {required bool isStart}) async {
    final current = isStart ? schedule.start : schedule.end;
    final parts = current.split(':');
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])));
    if (picked == null) return;

    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await _settings.setContextOwnDaySchedule(_target.id, weekday, isStart ? schedule.copyWith(start: value) : schedule.copyWith(end: value));
    await _pushContextSettings();
    if (mounted) setState(() {});
  }

  Future<void> _setDayEnabled(int weekday, WorkDaySchedule schedule, bool enabled) async {
    await _settings.setContextOwnDaySchedule(_target.id, weekday, schedule.copyWith(enabled: enabled));
    await _pushContextSettings();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(title: Text(_target.name), actions: [IconButton(icon: const Icon(Icons.edit), tooltip: tr('work_contexts.edit_basics'), onPressed: _editBasics)]),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(context),
            const SizedBox(height: 20),
            _buildScheduleCard(context),
            const SizedBox(height: 20),
            _buildMonthTargetsCard(context),
            const SizedBox(height: 20),
            _buildDayOverridesCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final projectRepo = context.read<ProjectRepository>();
    final projectNames = _target.projectIds.map((id) => projectRepo.getById(id)?.name ?? id).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.track_changes, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_target.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Text('${_target.targetHours.toStringAsFixed(0)} h', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              projectNames.isEmpty ? tr('monthly_targets.no_projects_selected') : projectNames,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context) {
    final usesOwn = _settings.getContextUsesOwnSchedule(_target.id);
    final dayNames = [
      tr('settings.monday'),
      tr('settings.tuesday'),
      tr('settings.wednesday'),
      tr('settings.thursday'),
      tr('settings.friday'),
      tr('settings.saturday'),
      tr('settings.sunday'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('settings.work_schedule'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              tr('work_contexts.own_schedule_desc'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('work_contexts.own_schedule')),
              subtitle: Text(usesOwn ? tr('work_contexts.own_schedule_on') : tr('work_contexts.own_schedule_off')),
              value: usesOwn,
              onChanged: _setUsesOwnSchedule,
            ),
            const Divider(),
            ...List.generate(7, (i) {
              final weekday = i + 1;
              final schedule = usesOwn ? _settings.getContextOwnDaySchedule(_target.id, weekday) : _settings.getWorkDaySchedule(weekday);
              return _ScheduleRow(
                label: dayNames[i],
                schedule: schedule,
                editable: usesOwn,
                onEnabledChanged: (value) => _setDayEnabled(weekday, schedule, value),
                onStartTap: () => _pickTime(weekday, schedule, isStart: true),
                onEndTap: () => _pickTime(weekday, schedule, isStart: false),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthTargetsCard(BuildContext context) {
    final exceptions = _settings.getContextMonthTargets(_target.id).entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('work_contexts.month_targets'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              tr('work_contexts.month_targets_desc', namedArgs: {'hours': _target.targetHours.toStringAsFixed(0)}),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 8),
            if (exceptions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  tr('work_contexts.no_month_targets'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
              )
            else
              ...exceptions.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: const Icon(Icons.event_note, size: 20),
                  title: Text(_formatMonthKey(entry.key)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${entry.value.toStringAsFixed(0)} h', style: const TextStyle(fontWeight: FontWeight.w600)),
                      IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _removeMonthTarget(entry.key)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton.icon(onPressed: _addMonthTarget, icon: const Icon(Icons.add, size: 18), label: Text(tr('work_contexts.add_month_target'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayOverridesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('settings.day_overrides'), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DayOverridesCalendar(settingsRepository: _settings, syncService: _sync, contextId: _target.id, onChanged: () => setState(() {})),
          ],
        ),
      ),
    );
  }

  String _formatMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return key;
    return DateFormat('LLLL yyyy', context.locale.languageCode).format(DateTime(year, month));
  }

  Future<void> _removeMonthTarget(String monthKey) async {
    final parts = monthKey.split('-');
    final year = int.tryParse(parts.first);
    final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (year == null || month == null) return;

    await _settings.setContextMonthTarget(_target.id, year, month, null);
    await _pushContextSettings();
    if (mounted) setState(() {});
  }

  Future<void> _addMonthTarget() async {
    final now = DateTime.now();
    int year = now.year;
    int month = now.month;
    final hoursController = TextEditingController(text: _target.targetHours.toStringAsFixed(0));

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(tr('work_contexts.add_month_target')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setDialogState(() {
                      month--;
                      if (month < 1) {
                        month = 12;
                        year--;
                      }
                    }),
                  ),
                  Text(DateFormat('LLLL yyyy', ctx.locale.languageCode).format(DateTime(year, month)), style: Theme.of(ctx).textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setDialogState(() {
                      month++;
                      if (month > 12) {
                        month = 1;
                        year++;
                      }
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: hoursController,
                decoration: InputDecoration(labelText: tr('monthly_targets.target_hours'), suffixText: 'h'),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('common.cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tr('common.save'))),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final hours = double.tryParse(hoursController.text.replaceAll(',', '.'));
    if (hours == null || hours < 0) return;

    await _settings.setContextMonthTarget(_target.id, year, month, hours);
    await _pushContextSettings();
    if (mounted) setState(() {});
  }

  Future<void> _editBasics() async {
    final projectRepo = context.read<ProjectRepository>();
    final targetRepo = context.read<MonthlyHoursTargetRepository>();
    final allProjects = projectRepo.getActive();

    final nameController = TextEditingController(text: _target.name);
    final hoursController = TextEditingController(text: _target.targetHours.toStringAsFixed(0));
    final selectedProjectIds = List<String>.from(_target.projectIds);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(tr('work_contexts.edit_basics')),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameController, decoration: InputDecoration(labelText: tr('monthly_targets.target_name'))),
                const SizedBox(height: 16),
                TextField(
                  controller: hoursController,
                  decoration: InputDecoration(labelText: tr('monthly_targets.target_hours'), suffixText: 'h'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Text(tr('monthly_targets.select_projects'), style: Theme.of(ctx).textTheme.titleSmall),
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
                          onSelected: (selected) => setDialogState(() {
                            if (selected) {
                              selectedProjectIds.add(project.id);
                            } else {
                              selectedProjectIds.remove(project.id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('common.cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tr('common.save'))),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final name = nameController.text.trim();
    final hours = double.tryParse(hoursController.text.replaceAll(',', '.')) ?? 0;
    if (name.isEmpty || hours <= 0 || selectedProjectIds.isEmpty) return;

    final updated = _target.copyWith(name: name, targetHours: hours, projectIds: selectedProjectIds);
    await targetRepo.update(updated);
    await _sync?.pushMonthlyTarget(updated);
    if (mounted) setState(() => _target = updated);
  }
}

class _ScheduleRow extends StatelessWidget {
  final String label;
  final WorkDaySchedule schedule;
  final bool editable;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;

  const _ScheduleRow({
    required this.label,
    required this.schedule,
    required this.editable,
    required this.onEnabledChanged,
    required this.onStartTap,
    required this.onEndTap,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Checkbox(value: schedule.enabled, onChanged: editable ? (v) => onEnabledChanged(v ?? false) : null),
          ),
          Expanded(
            child: Text(label, style: TextStyle(color: schedule.enabled ? null : dimmed), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          _TimeButton(time: schedule.start, enabled: editable && schedule.enabled, onTap: onStartTap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('—', style: TextStyle(color: schedule.enabled ? null : dimmed)),
          ),
          _TimeButton(time: schedule.end, enabled: editable && schedule.enabled, onTap: onEndTap),
          const SizedBox(width: 8),
          if (schedule.enabled)
            Text(
              _formatHours(schedule.hours),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }

  static String _formatHours(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}

class _TimeButton extends StatelessWidget {
  final String time;
  final bool enabled;
  final VoidCallback onTap;

  const _TimeButton({required this.time, required this.enabled, required this.onTap});

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
