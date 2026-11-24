import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/time_formatter.dart';
import '../../data/models/pomodoro_session.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/running_timer_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../blocs/pomodoro/pomodoro_bloc.dart';
import '../blocs/pomodoro/pomodoro_event.dart';
import '../blocs/pomodoro/pomodoro_state.dart';
import '../blocs/timer/timer_bloc.dart';
import '../blocs/timer/timer_event.dart';
import '../screens/pomodoro_screen.dart';
import 'start_timer_dialog.dart';

class PomodoroColors {
  const PomodoroColors._();

  static const Color work = Color(0xFFE5533D);
  static const Color rest = Color(0xFF2E9E83);

  static Color of(PomodoroPhase phase) => phase == PomodoroPhase.work ? work : rest;
}

String formatPomodoroCountdown(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final minutes = s ~/ 60;
  return '${minutes.toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

String pomodoroPhaseLabel(PomodoroPhase phase) => switch (phase) {
  PomodoroPhase.work => tr('pomodoro.phase_work'),
  PomodoroPhase.shortBreak => tr('pomodoro.phase_short_break'),
  PomodoroPhase.longBreak => tr('pomodoro.phase_long_break'),
};

/// Compact pomodoro control shown on the Time Tracking screen.
class PomodoroCard extends StatelessWidget {
  const PomodoroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PomodoroBloc, PomodoroState>(
      listenWhen: (previous, current) => current.startConflict != null && previous.startConflict != current.startConflict,
      listener: (context, state) => showPomodoroStartConflict(context, state.startConflict!, state.now),
      builder: (context, state) {
        if (!state.showOnTimeTracking) return const SizedBox.shrink();
        final session = state.session;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PomodoroScreen(standalone: true))),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: session == null ? _IdleContent(state: state) : _ActiveContent(state: state, session: session),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> showPomodoroStartConflict(BuildContext context, PomodoroSession running, DateTime now) async {
  final bloc = context.read<PomodoroBloc>();
  final replace = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('pomodoro.conflict_title')),
      content: Text(
        tr(
          'pomodoro.conflict_message',
          namedArgs: {
            'device': running.startDevice.isEmpty ? '?' : running.startDevice,
            'phase': pomodoroPhaseLabel(running.phase),
            'remaining': formatPomodoroCountdown(running.remainingSeconds(now)),
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(tr('pomodoro.conflict_replace'))),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(tr('pomodoro.conflict_take_over'))),
      ],
    ),
  );
  if (replace == true) bloc.add(const StartPomodoro(replaceExisting: true));
}

/// Starts a pomodoro from the app window, asking first when no project timer runs.
Future<void> startPomodoroFromUi(BuildContext context, PomodoroState state) async {
  final bloc = context.read<PomodoroBloc>();
  if (!state.settings.warnWhenNoTimer || context.read<RunningTimerRepository>().hasRunningTimers) {
    bloc.add(const StartPomodoro());
    return;
  }
  final choice = await showDialog<_NoTimerChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('pomodoro.no_timer_title')),
      content: Text(tr('pomodoro.no_timer_dialog')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(tr('common.cancel'))),
        TextButton(onPressed: () => Navigator.pop(dialogContext, _NoTimerChoice.withoutTimer), child: Text(tr('pomodoro.no_timer_continue'))),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, _NoTimerChoice.startTimer), child: Text(tr('pomodoro.no_timer_start_timer'))),
      ],
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == _NoTimerChoice.withoutTimer) {
    bloc.add(const StartPomodoro());
    return;
  }
  final timerBloc = context.read<TimerBloc>();
  final settingsRepo = context.read<SettingsRepository>();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StartTimerDialog(
      projects: context.read<ProjectRepository>().getActive(),
      onStart: (project, task, notes) {
        settingsRepo.addRecentTask(project.id, task.id);
        timerBloc.add(StartTimer(projectId: project.id, taskId: task.id, notes: notes));
        bloc.add(const StartPomodoro(timerStarted: true));
      },
    ),
  );
}

String pomodoroStatusText(PomodoroSession session, int rounds) {
  if (session.isAwaitingStart) return tr(session.phase == PomodoroPhase.work ? 'pomodoro.waiting_work' : 'pomodoro.waiting_break');
  if (session.isPaused) return tr('pomodoro.paused');
  return tr('pomodoro.round', namedArgs: {'round': '${session.round(rounds)}', 'total': '$rounds'});
}

class _IdleContent extends StatelessWidget {
  final PomodoroState state;

  const _IdleContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: PomodoroColors.work.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Text('🍅', style: TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('pomodoro.title'), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                tr('pomodoro.today_count', namedArgs: {'count': '${state.todayCompleted}'}),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () => startPomodoroFromUi(context, state),
          style: FilledButton.styleFrom(backgroundColor: PomodoroColors.work, foregroundColor: Colors.white),
          icon: const Icon(Icons.play_arrow),
          label: Text(tr('pomodoro.start')),
        ),
      ],
    );
  }
}

enum _NoTimerChoice { startTimer, withoutTimer }

class _ActiveContent extends StatelessWidget {
  final PomodoroState state;
  final PomodoroSession session;

  const _ActiveContent({required this.state, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = state.now;
    final color = PomodoroColors.of(session.phase);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final rounds = state.settings.roundsBeforeLongBreak;

    final status = pomodoroStatusText(session, rounds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(value: session.progress(now), strokeWidth: 5, backgroundColor: color.withValues(alpha: 0.15), color: color),
                  ),
                  Text(session.phase == PomodoroPhase.work ? '🍅' : '☕', style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pomodoroPhaseLabel(session.phase),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              formatPomodoroCountdown(session.remainingSeconds(now)),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: session.isRunning ? null : muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
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
            ),
            PomodoroControls(session: session, color: color),
          ],
        ),
      ],
    );
  }
}

class PomodoroControls extends StatelessWidget {
  final PomodoroSession session;
  final Color color;

  const PomodoroControls({super.key, required this.session, required this.color});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PomodoroBloc>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (session.isAwaitingStart)
          Flexible(
            child: FilledButton.icon(
              onPressed: () => bloc.add(const StartPendingPomodoroPhase()),
              style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
              icon: const Icon(Icons.play_arrow),
              label: Text(tr(session.phase == PomodoroPhase.work ? 'pomodoro.start_work' : 'pomodoro.start_break'), overflow: TextOverflow.ellipsis),
            ),
          )
        else ...[
          IconButton(
            tooltip: tr(session.isPaused ? 'pomodoro.resume' : 'pomodoro.pause'),
            onPressed: () => bloc.add(session.isPaused ? const ResumePomodoro() : const PausePomodoro()),
            icon: Icon(session.isPaused ? Icons.play_arrow : Icons.pause),
          ),
          IconButton(tooltip: tr('pomodoro.skip'), onPressed: () => bloc.add(const SkipPomodoroPhase()), icon: const Icon(Icons.skip_next)),
        ],
        IconButton(tooltip: tr('pomodoro.stop'), onPressed: () => bloc.add(const StopPomodoro()), icon: const Icon(Icons.stop)),
      ],
    );
  }
}
