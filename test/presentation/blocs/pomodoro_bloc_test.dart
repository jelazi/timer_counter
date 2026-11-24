import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timer_counter/core/services/pomodoro_alerts.dart';
import 'package:timer_counter/core/services/pomodoro_engine.dart';
import 'package:timer_counter/data/models/pomodoro_session.dart';
import 'package:timer_counter/data/models/pomodoro_settings.dart';
import 'package:timer_counter/data/repositories/pomodoro_repository.dart';
import 'package:timer_counter/data/repositories/running_timer_repository.dart';
import 'package:timer_counter/presentation/blocs/pomodoro/pomodoro_bloc.dart';
import 'package:timer_counter/presentation/blocs/pomodoro/pomodoro_event.dart';
import 'package:timer_counter/presentation/blocs/pomodoro/pomodoro_state.dart';

class _MockRunningTimers extends Mock implements RunningTimerRepository {}

class _FakeAlerts implements PomodoroAlerts {
  int noTimer = 0;
  int workStarts = 0;
  int ticks = 0;
  bool granted = true;
  int permissionRequests = 0;
  final ended = <PomodoroTransition>[];
  final warnings = <int>[];
  final scheduled = <PomodoroSession?>[];
  final previews = <String>[];
  final taps = StreamController<void>.broadcast();

  @override
  Stream<void> get startPendingRequests => taps.stream;

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission({bool fromUser = false}) async => permissionRequests++;

  @override
  Future<bool> permissionGranted() async => granted;

  @override
  Future<void> noTimerRunning() async => noTimer++;

  @override
  Future<void> phaseEnded(PomodoroTransition transition, PomodoroSession next) async => ended.add(transition);

  @override
  Future<void> workStarted() async => workStarts++;

  @override
  Future<void> warning(PomodoroSession session, int minutesLeft) async => warnings.add(minutesLeft);

  @override
  Future<void> tick() async => ticks++;

  @override
  Future<void> reschedule(PomodoroSession? session) async => scheduled.add(session);

  @override
  Future<void> preview(String soundId) async => previews.add(soundId);
}

void main() {
  late Directory tempDir;
  late PomodoroRepository repo;
  late _MockRunningTimers timers;
  late DateTime now;
  late _FakeAlerts notifier;

  final t0 = DateTime(2026, 11, 24, 9);
  DateTime at(int minutes, [int seconds = 0]) => t0.add(Duration(minutes: minutes, seconds: seconds));

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  PomodoroBloc build() => PomodoroBloc(repository: repo, runningTimerRepository: timers, clock: () => now, deviceLabel: 'macOS', tickInterval: null, alerts: notifier);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('timer_counter_pomodoro_test');
    Hive.init(tempDir.path);
    repo = PomodoroRepository();
    await repo.init();
    timers = _MockRunningTimers();
    when(() => timers.hasRunningTimers).thenReturn(false);
    now = t0;
    notifier = _FakeAlerts();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  blocTest<PomodoroBloc, PomodoroState>(
    'start creates a persisted running work session',
    build: build,
    wait: const Duration(milliseconds: 50),
    setUp: () => when(() => timers.hasRunningTimers).thenReturn(true),
    act: (bloc) => bloc.add(const StartPomodoro()),
    verify: (bloc) {
      final session = repo.getSession()!;
      expect(session.phase, PomodoroPhase.work);
      expect(session.isRunning, isTrue);
      expect(session.startedWithTimer, isTrue);
      expect(session.startDevice, 'macOS');
      expect(bloc.state.session, session);
    },
  );

  blocTest<PomodoroBloc, PomodoroState>(
    'a second start keeps the running session',
    build: build,
    wait: const Duration(milliseconds: 50),
    act: (bloc) async {
      bloc.add(const StartPomodoro());
      await settle();
      now = at(3);
      bloc.add(const StartPomodoro());
    },
    verify: (bloc) => expect(repo.getSession()!.startedAt, t0),
  );

  blocTest<PomodoroBloc, PomodoroState>(
    'a tick past the phase end moves to the break and stores it',
    build: build,
    wait: const Duration(milliseconds: 50),
    act: (bloc) async {
      bloc.add(const StartPomodoro());
      await settle();
      now = at(26);
      bloc.add(const TickPomodoro());
    },
    verify: (bloc) {
      expect(bloc.state.session!.phase, PomodoroPhase.shortBreak);
      expect(repo.getSession()!.phase, PomodoroPhase.shortBreak);
      expect(bloc.state.todayCompleted, 1);
    },
  );

  blocTest<PomodoroBloc, PomodoroState>(
    'stop files a history record and clears the session',
    build: build,
    wait: const Duration(milliseconds: 50),
    act: (bloc) async {
      bloc.add(const StartPomodoro());
      await settle();
      now = at(30);
      bloc.add(const StopPomodoro());
    },
    verify: (bloc) {
      expect(repo.getSession(), isNull);
      expect(bloc.state.session, isNull);
      final records = repo.getRecords();
      expect(records, hasLength(1));
      expect(records.single.completedPomodoros, 1);
      expect(records.single.workSeconds, 25 * 60);
      expect(records.single.breakSeconds, 5 * 60);
      expect(bloc.state.todayCompleted, 1);
    },
  );

  blocTest<PomodoroBloc, PomodoroState>(
    'pause, resume, skip and confirming the waiting phase',
    build: build,
    wait: const Duration(milliseconds: 50),
    act: (bloc) async {
      bloc.add(const StartPomodoro());
      await settle();
      now = at(5);
      bloc.add(const PausePomodoro());
      await settle();
      expect(repo.getSession()!.isPaused, isTrue);
      now = at(6);
      bloc.add(const ResumePomodoro());
      await settle();
      expect(repo.getSession()!.pausedSeconds, 60);
      bloc.add(const SkipPomodoroPhase());
      await settle();
      expect(repo.getSession()!.phase, PomodoroPhase.shortBreak);
      now = at(12);
      bloc.add(const TickPomodoro());
      await settle();
      expect(repo.getSession()!.isAwaitingStart, isTrue);
      now = at(13);
      bloc.add(const StartPendingPomodoroPhase());
    },
    verify: (bloc) {
      final s = repo.getSession()!;
      expect(s.phase, PomodoroPhase.work);
      expect(s.isRunning, isTrue);
      expect(s.waitingSeconds, 2 * 60);
      expect(s.completedPomodoros, 0);
    },
  );

  blocTest<PomodoroBloc, PomodoroState>(
    'loading a session left idle for more than a cycle ends it by inactivity',
    build: build,
    wait: const Duration(milliseconds: 50),
    setUp: () async {
      await repo.setLiveState(
        PomodoroLiveState(
          session: PomodoroSession(
            id: 'old',
            startedAt: t0,
            phase: PomodoroPhase.work,
            status: PomodoroStatus.awaitingStart,
            phaseStartedAt: t0,
            phaseDurationSeconds: 1500,
            updatedAt: t0,
          ),
          updatedAt: t0,
        ),
      );
      now = at(200);
    },
    act: (bloc) => bloc.add(const LoadPomodoro()),
    verify: (bloc) {
      expect(bloc.state.session, isNull);
      expect(repo.getSession(), isNull);
      expect(repo.getRecords().single.endReason, PomodoroEndReason.inactivity);
    },
  );

  blocTest<PomodoroBloc, PomodoroState>(
    'settings and visibility are stored',
    build: build,
    wait: const Duration(milliseconds: 50),
    act: (bloc) async {
      bloc.add(const UpdatePomodoroSettings(PomodoroSettings(workMinutes: 50)));
      await settle();
      bloc.add(const TogglePomodoroVisibility(false));
    },
    verify: (bloc) {
      expect(repo.getSettings().workMinutes, 50);
      expect(repo.getSettings().updatedAt, t0);
      expect(repo.getShowOnTimeTracking(), isFalse);
      expect(bloc.state.settings.workMinutes, 50);
      expect(bloc.state.showOnTimeTracking, isFalse);
    },
  );

  blocTest<PomodoroBloc, PomodoroState>(
    'starting while a session runs reports the conflict instead of replacing it',
    build: build,
    wait: const Duration(milliseconds: 50),
    act: (bloc) async {
      bloc.add(const StartPomodoro());
      await settle();
      now = at(3);
      bloc.add(const StartPomodoro());
    },
    verify: (bloc) {
      expect(bloc.state.startConflict?.startedAt, t0);
      expect(repo.getSession()!.startedAt, t0);
      expect(repo.getRecords(), isEmpty);
    },
  );

  blocTest<PomodoroBloc, PomodoroState>(
    'replacing ends the running session into the history and starts a new one',
    build: build,
    wait: const Duration(milliseconds: 50),
    act: (bloc) async {
      bloc.add(const StartPomodoro());
      await settle();
      now = at(3);
      bloc.add(const StartPomodoro(replaceExisting: true));
    },
    verify: (bloc) {
      final live = repo.getLiveState();
      expect(live.session!.startedAt, at(3));
      final old = repo.getRecords().single;
      expect(old.workSeconds, 3 * 60);
      expect(live.endedSessionIds, [old.id]);
      expect(bloc.state.startConflict, isNull);
    },
  );

  blocTest<PomodoroBloc, PomodoroState>(
    'stopping keeps the ended id so a stale device cannot revive the session',
    build: build,
    wait: const Duration(milliseconds: 50),
    act: (bloc) async {
      bloc.add(const StartPomodoro());
      await settle();
      now = at(4);
      bloc.add(const StopPomodoro());
    },
    verify: (bloc) {
      final live = repo.getLiveState();
      expect(live.session, isNull);
      expect(live.endedSessionIds, [repo.getRecords().single.id]);
      expect(live.updatedAt, at(4));
    },
  );

  group('no-timer warning', () {
    blocTest<PomodoroBloc, PomodoroState>(
      'a start from the tray without a timer notifies once',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(const StartPomodoro(notifyIfNoTimer: true)),
      verify: (_) => expect(notifier.noTimer, 1),
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'no notification with a running timer, a timer started alongside, or the warning off',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) async {
        bloc.add(const StartPomodoro(notifyIfNoTimer: true, timerStarted: true));
        await settle();
        bloc.add(const StopPomodoro());
        await settle();
        when(() => timers.hasRunningTimers).thenReturn(true);
        bloc.add(const StartPomodoro(notifyIfNoTimer: true));
        await settle();
        bloc.add(const StopPomodoro());
        await settle();
        when(() => timers.hasRunningTimers).thenReturn(false);
        bloc.add(const UpdatePomodoroSettings(PomodoroSettings(warnWhenNoTimer: false)));
        await settle();
        bloc.add(const StartPomodoro(notifyIfNoTimer: true));
      },
      verify: (bloc) {
        expect(notifier.noTimer, 0);
        expect(repo.getRecords().first.startedWithTimer, isTrue);
      },
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'a start from the card does not notify (its dialog asked already)',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(const StartPomodoro()),
      verify: (_) => expect(notifier.noTimer, 0),
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'every later work phase warns: confirmed, skipped into, or auto-started just now',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) async {
        await repo.setSettings(const PomodoroSettings(autoStartWork: true));
        bloc.add(const StartPomodoro());
        await settle();
        bloc.add(const SkipPomodoroPhase());
        await settle();
        expect(notifier.noTimer, 0);
        bloc.add(const SkipPomodoroPhase());
        await settle();
        expect(notifier.noTimer, 1);
        now = at(25, 10);
        bloc.add(const TickPomodoro());
        await settle();
        expect(notifier.noTimer, 1);
        now = at(30, 5);
        bloc.add(const TickPomodoro());
        await settle();
        expect(notifier.noTimer, 2);
        await repo.setSettings(const PomodoroSettings());
        now = at(55, 10);
        bloc.add(const TickPomodoro());
        await settle();
        now = at(60, 10);
        bloc.add(const TickPomodoro());
        await settle();
        expect(repo.getSession()!.isAwaitingStart, isTrue);
        bloc.add(const StartPendingPomodoroPhase());
      },
      verify: (_) => expect(notifier.noTimer, 3),
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'a work phase replayed long after it started does not warn',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) async {
        await repo.setSettings(const PomodoroSettings(autoStartWork: true));
        bloc.add(const StartPomodoro());
        await settle();
        now = at(45);
        bloc.add(const TickPomodoro());
      },
      verify: (bloc) {
        expect(bloc.state.session!.phase, PomodoroPhase.work);
        expect(notifier.noTimer, 0);
      },
    );
  });

  group('sounds and notifications', () {
    blocTest<PomodoroBloc, PomodoroState>(
      'start sounds work start and plans the notifications ahead',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(const StartPomodoro()),
      verify: (_) {
        expect(notifier.workStarts, 1);
        expect(notifier.scheduled.last?.isRunning, isTrue);
        expect(notifier.permissionRequests, 0);
      },
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'a phase end that just happened is announced once; one replayed later is not',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) async {
        bloc.add(const StartPomodoro());
        await settle();
        now = at(25, 2);
        bloc.add(const TickPomodoro());
        await settle();
        bloc.add(const TickPomodoro());
        await settle();
        expect(notifier.ended.map((t) => t.to), [PomodoroPhase.shortBreak]);
        now = at(45);
        bloc.add(const TickPomodoro());
      },
      verify: (bloc) {
        expect(bloc.state.session!.isAwaitingStart, isTrue);
        expect(notifier.ended, hasLength(1));
      },
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'the warning sounds once when the countdown crosses it, not when opened later in the phase',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) async {
        bloc.add(const StartPomodoro());
        await settle();
        now = at(23, 59);
        bloc.add(const TickPomodoro());
        await settle();
        expect(notifier.warnings, isEmpty);
        now = at(24, 1);
        bloc.add(const TickPomodoro());
        await settle();
        now = at(24, 2);
        bloc.add(const TickPomodoro());
        await settle();
        expect(notifier.warnings, [1]);
        now = at(29, 50);
        bloc.add(const TickPomodoro());
      },
      verify: (_) => expect(notifier.warnings, [1]),
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'ticking only during running work and only when switched on',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) async {
        bloc.add(const StartPomodoro());
        await settle();
        bloc.add(const TickPomodoro());
        await settle();
        expect(notifier.ticks, 0);
        bloc.add(const UpdatePomodoroSettings(PomodoroSettings(ticking: true)));
        await settle();
        bloc.add(const TickPomodoro());
        await settle();
        bloc.add(const PausePomodoro());
        await settle();
        bloc.add(const TickPomodoro());
      },
      verify: (_) => expect(notifier.ticks, 1),
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'tapping the notification of a waiting phase starts it',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) async {
        bloc.add(const StartPomodoro());
        await settle();
        now = at(31);
        bloc.add(const TickPomodoro());
        await settle();
        expect(bloc.state.session!.isAwaitingStart, isTrue);
        notifier.taps.add(null);
      },
      verify: (bloc) {
        expect(bloc.state.session!.isRunning, isTrue);
        expect(bloc.state.session!.phase, PomodoroPhase.work);
        expect(notifier.workStarts, 2);
      },
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'without permission the first start asks for it and the state reports the answer',
      build: build,
      wait: const Duration(milliseconds: 50),
      setUp: () => notifier.granted = false,
      act: (bloc) async {
        bloc.add(const LoadPomodoro());
        await settle();
        bloc.add(const StartPomodoro());
      },
      verify: (bloc) {
        expect(notifier.permissionRequests, 1);
        expect(bloc.state.notificationsPermitted, isFalse);
      },
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'device switches are stored, re-plan the notifications, and preview plays the chosen sound',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) async {
        bloc.add(const StartPomodoro());
        await settle();
        final before = notifier.scheduled.length;
        bloc.add(const TogglePomodoroDeviceNotifications(false));
        await settle();
        expect(notifier.scheduled.length, before + 1);
        bloc.add(const TogglePomodoroDeviceSounds(false));
        await settle();
        bloc.add(const PreviewPomodoroSound('bell'));
      },
      verify: (bloc) {
        expect(repo.getNotificationsOnDevice(), isFalse);
        expect(repo.getSoundsOnDevice(), isFalse);
        expect(bloc.state.notificationsOnDevice, isFalse);
        expect(bloc.state.soundsOnDevice, isFalse);
        expect(notifier.previews, ['bell']);
      },
    );
  });

  group('history', () {
    blocTest<PomodoroBloc, PomodoroState>(
      'a finished session shows in the history; delete and undo',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) async {
        bloc.add(const StartPomodoro());
        await settle();
        now = at(26);
        bloc.add(const StopPomodoro());
        await settle();
        expect(bloc.state.history, hasLength(1));
        final record = bloc.state.history.single;
        bloc.add(DeletePomodoroRecord(record.id));
        await settle();
        expect(bloc.state.history, isEmpty);
        expect(bloc.state.todayCompleted, 0);
        bloc.add(RestorePomodoroRecord(record));
      },
      verify: (bloc) {
        expect(bloc.state.history, hasLength(1));
        expect(repo.getRecords(), hasLength(1));
        expect(bloc.state.todayCompleted, 1);
      },
    );

    blocTest<PomodoroBloc, PomodoroState>(
      'the bottom-bar tab switch is stored on the device',
      build: build,
      wait: const Duration(milliseconds: 50),
      act: (bloc) => bloc.add(const TogglePomodoroMobileTab(true)),
      verify: (bloc) {
        expect(repo.getMobileTab(), isTrue);
        expect(bloc.state.mobileTab, isTrue);
      },
    );
  });
}
