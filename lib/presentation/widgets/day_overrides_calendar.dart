import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/services/pocketbase_sync_service.dart';
import '../../data/repositories/settings_repository.dart';

/// Month calendar for marking days off and extra work days.
///
/// Without [contextId] it edits the global overrides. With one it edits that
/// work context's own overrides, which win over the global ones for its
/// projects; days the context does not override are drawn as inherited.
class DayOverridesCalendar extends StatefulWidget {
  final SettingsRepository settingsRepository;
  final PocketBaseSyncService? syncService;
  final String? contextId;

  /// Called after an override changed, so an enclosing screen can refresh.
  final VoidCallback? onChanged;

  const DayOverridesCalendar({super.key, required this.settingsRepository, required this.syncService, this.contextId, this.onChanged});

  @override
  State<DayOverridesCalendar> createState() => _DayOverridesCalendarState();
}

class _DayOverridesCalendarState extends State<DayOverridesCalendar> {
  late int _year;
  late int _month;

  String? get _contextId => widget.contextId;

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
    final contextId = _contextId;
    final syncService = widget.syncService;

    if (contextId == null) {
      final currentOverride = repo.getDayOverride(date);
      final isNormallyWorkDay = repo.getWorkScheduleEnabled(date.weekday);
      final newOverride = _nextOverride(currentOverride, isNormallyWorkDay);

      await repo.setDayOverride(date, newOverride);
      if (newOverride == null) {
        await syncService?.deleteDayOverride(date);
      } else {
        await syncService?.pushDayOverride(date, newOverride);
      }
    } else {
      final currentOverride = repo.getContextDayOverride(contextId, date);
      // Cycle relative to what the context would inherit, so clearing the
      // override always lands back on the global answer.
      final globalOverride = repo.getDayOverride(date);
      final inheritedIsWorkDay = switch (globalOverride) {
        'work' => true,
        'off' => false,
        _ => repo.getEffectiveDaySchedule(date.weekday, contextId: contextId).enabled,
      };
      final newOverride = _nextOverride(currentOverride, inheritedIsWorkDay);

      await repo.setContextDayOverride(contextId, date, newOverride);
      if (newOverride == null) {
        await syncService?.deleteContextDayOverride(contextId, date);
      } else {
        await syncService?.pushContextDayOverride(contextId, date, newOverride);
      }
    }

    widget.onChanged?.call();
    if (!mounted) return;
    setState(() {});
  }

  static String? _nextOverride(String? current, bool isWorkDay) {
    if (isWorkDay) return current == 'off' ? null : 'off';
    return current == 'work' ? null : 'work';
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.settingsRepository;
    final contextId = _contextId;
    final overrides = contextId == null ? repo.getDayOverridesForMonth(_year, _month) : repo.getContextDayOverridesForMonth(contextId, _year, _month);
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final firstWeekday = DateTime(_year, _month, 1).weekday; // 1=Mon
    final locale = context.locale.languageCode;
    final monthName = DateFormat('MMMM yyyy', locale).format(DateTime(_year, _month));

    int workDays = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      if (repo.isWorkDay(DateTime(_year, _month, d), contextId: contextId)) workDays++;
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
        Text(
          contextId == null ? tr('settings.day_overrides_desc') : tr('work_contexts.day_overrides_desc'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: _previousMonth),
            Text('${monthName[0].toUpperCase()}${monthName.substring(1)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            tr('settings.work_days_count', namedArgs: {'count': workDays.toString()}),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 8),
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
        ..._buildCalendarRows(context, daysInMonth, firstWeekday, overrides),
        const SizedBox(height: 12),
        Text(
          tr('settings.tap_to_toggle'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _legendItem(context, Colors.green.shade100, tr('settings.normal_work_day')),
            _legendItem(context, Colors.red.shade100, tr('settings.day_off')),
            _legendItem(context, Colors.blue.shade100, tr('settings.extra_work_day')),
            if (contextId != null) _legendItem(context, Colors.orange.shade100, tr('work_contexts.inherited_day')),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildCalendarRows(BuildContext context, int daysInMonth, int firstWeekday, Map<DateTime, String> overrides) {
    final rows = <Widget>[];
    final cells = <Widget>[];

    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const Expanded(child: SizedBox(height: 36)));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_year, _month, day);
      final override = overrides[date];
      final inheritedOverride = _contextId == null ? null : widget.settingsRepository.getDayOverride(date);
      final isEffectiveWorkDay = widget.settingsRepository.isWorkDay(date, contextId: _contextId);

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
      } else if (inheritedOverride != null) {
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
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
            onTap: () => _toggleDay(date),
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

  Widget _legendItem(BuildContext context, Color bgColor, String label) {
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
