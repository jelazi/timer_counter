import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/pomodoro_stats.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/pomodoro_session.dart';
import '../blocs/pomodoro/pomodoro_bloc.dart';
import '../blocs/pomodoro/pomodoro_event.dart';
import '../blocs/pomodoro/pomodoro_state.dart';
import '../widgets/desktop/pane_header.dart';
import '../widgets/pomodoro_card.dart';

/// The pomodoro with a large countdown, today / week summary and the history.
class PomodoroScreen extends StatelessWidget {
  /// Pushed as its own route (from the card) rather than shown as a section.
  final bool standalone;

  const PomodoroScreen({super.key, this.standalone = false});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PomodoroBloc, PomodoroState>(
      listenWhen: (previous, current) => current.startConflict != null && previous.startConflict != current.startConflict,
      listener: (context, state) => showPomodoroStartConflict(context, state.startConflict!, state.now),
      builder: (context, state) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        final content = ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          children: [
            if (!standalone && isMobile) ...[
              Text(tr('pomodoro.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
            ],
            _TimerPanel(state: state),
            const SizedBox(height: 16),
            _Summary(state: state),
            const SizedBox(height: 24),
            Text(tr('pomodoro.history'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._history(context, state),
          ],
        );

        if (standalone) {
          return Scaffold(
            appBar: AppBar(title: Text(tr('pomodoro.title'))),
            body: content,
          );
        }
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isMobile && PlatformUtils.isDesktop)
                PaneHeader(
                  title: tr('pomodoro.title'),
                  subtitle: tr('pomodoro.today_count', namedArgs: {'count': '${state.todayCompleted}'}),
                ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _history(BuildContext context, PomodoroState state) {
    final theme = Theme.of(context);
    if (state.history.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(tr('pomodoro.history_empty'), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ),
        ),
      ];
    }
    final locale = context.locale.languageCode;
    return [
      for (final group in PomodoroStats.byDay(state.history)) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(DateFormat('EEEE d. MMMM', locale).format(group.day), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < group.records.length; i++) ...[if (i > 0) const Divider(height: 1), _RecordTile(key: ValueKey(group.records[i].id), record: group.records[i])],
            ],
          ),
        ),
      ],
    ];
  }
}

class _TimerPanel extends StatelessWidget {
  final PomodoroState state;

  const _TimerPanel({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = state.session;
    final size = (MediaQuery.of(context).size.width * 0.55).clamp(160.0, 240.0);

    if (session == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('🍅', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              Text(
                formatPomodoroCountdown(state.settings.workMinutes * 60),
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => startPomodoroFromUi(context, state),
                style: FilledButton.styleFrom(backgroundColor: PomodoroColors.work, foregroundColor: Colors.white),
                icon: const Icon(Icons.play_arrow),
                label: Text(tr('pomodoro.start')),
              ),
            ],
          ),
        ),
      );
    }

    final now = state.now;
    final color = PomodoroColors.of(session.phase);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(value: session.progress(now), strokeWidth: 10, backgroundColor: color.withValues(alpha: 0.15), color: color),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pomodoroPhaseLabel(session.phase),
                        style: theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
                      ),
                      FittedBox(
                        child: Text(
                          formatPomodoroCountdown(session.remainingSeconds(now)),
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: session.isRunning ? null : muted,
                          ),
                        ),
                      ),
                      Text(
                        pomodoroStatusText(session, state.settings.roundsBeforeLongBreak),
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PomodoroControls(session: session, color: color),
            const SizedBox(height: 8),
            Text(
              tr(
                'pomodoro.session_summary',
                namedArgs: {
                  'total': TimeFormatter.formatHumanReadable(session.totalSeconds(now)),
                  'work': TimeFormatter.formatHumanReadable(session.liveWorkSeconds(now)),
                  'breaks': TimeFormatter.formatHumanReadable(session.liveBreakSeconds(now)),
                  'count': '${state.todayCompleted}',
                },
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final PomodoroState state;

  const _Summary({required this.state});

  @override
  Widget build(BuildContext context) {
    final now = state.now;
    final today = PomodoroStats.summarize(state.history, state.session, PomodoroStats.startOfDay(now), now);
    final week = PomodoroStats.summarize(state.history, state.session, PomodoroStats.startOfWeek(now), now);
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(title: tr('pomodoro.summary_today'), summary: today),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(title: tr('pomodoro.summary_week'), summary: week),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final PomodoroSummary summary;

  const _SummaryCard({required this.title, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            const SizedBox(height: 4),
            Text('${summary.pomodoros} 🍅', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              tr('pomodoro.summary_detail', namedArgs: {'work': TimeFormatter.formatHumanReadable(summary.workSeconds), 'sessions': '${summary.sessions}'}),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final PomodoroSessionRecord record;

  const _RecordTile({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat.Hm();
    final details = [
      tr('pomodoro.record_work', namedArgs: {'time': TimeFormatter.formatHumanReadable(record.workSeconds)}),
      tr('pomodoro.record_breaks', namedArgs: {'time': TimeFormatter.formatHumanReadable(record.breakSeconds)}),
      if (record.pausedSeconds >= 60) tr('pomodoro.record_paused', namedArgs: {'time': TimeFormatter.formatHumanReadable(record.pausedSeconds)}),
      if (record.waitingSeconds >= 60) tr('pomodoro.record_waiting', namedArgs: {'time': TimeFormatter.formatHumanReadable(record.waitingSeconds)}),
      if (record.endReason != PomodoroEndReason.manual) tr('pomodoro.end_reason_${record.endReason.name}'),
      if (record.startDevice.isNotEmpty) record.startDevice,
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: PomodoroColors.work.withValues(alpha: 0.12),
        child: Text(
          '${record.completedPomodoros}',
          style: theme.textTheme.titleSmall?.copyWith(color: PomodoroColors.work, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text('${time.format(record.startedAt)} – ${time.format(record.endedAt)} · ${record.completedPomodoros} 🍅'),
      subtitle: Text(details),
      trailing: IconButton(tooltip: tr('common.delete'), icon: const Icon(Icons.delete_outline), onPressed: () => _delete(context)),
    );
  }

  void _delete(BuildContext context) {
    final bloc = context.read<PomodoroBloc>();
    bloc.add(DeletePomodoroRecord(record.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('pomodoro.record_deleted')),
        duration: const Duration(seconds: 10),
        persist: false,
        action: SnackBarAction(label: tr('common.undo'), onPressed: () => bloc.add(RestorePomodoroRecord(record))),
      ),
    );
  }
}
