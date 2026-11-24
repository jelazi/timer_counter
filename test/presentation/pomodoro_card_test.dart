import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:timer_counter/data/models/pomodoro_session.dart';
import 'package:timer_counter/data/models/pomodoro_settings.dart';
import 'package:timer_counter/data/repositories/pomodoro_repository.dart';
import 'package:timer_counter/data/repositories/running_timer_repository.dart';
import 'package:timer_counter/presentation/blocs/pomodoro/pomodoro_bloc.dart';
import 'package:timer_counter/presentation/blocs/pomodoro/pomodoro_event.dart';
import 'package:timer_counter/presentation/widgets/pomodoro_card.dart';

class _MockRunningTimers extends Mock implements RunningTimerRepository {}

class _MockPomodoroRepository extends Mock implements PomodoroRepository {}

void main() {
  late _MockPomodoroRepository repo;
  late _MockRunningTimers timers;
  final t0 = DateTime(2026, 11, 24, 9);

  setUpAll(() async {
    registerFallbackValue(PomodoroLiveState.empty);
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    repo = _MockPomodoroRepository();
    timers = _MockRunningTimers();
    when(() => timers.hasRunningTimers).thenReturn(false);
    when(() => repo.getSettings()).thenReturn(const PomodoroSettings());
    when(() => repo.getSession()).thenReturn(null);
    when(() => repo.getLiveState()).thenReturn(PomodoroLiveState.empty);
    when(() => repo.getRecords()).thenReturn(const []);
    when(() => repo.getShowOnTimeTracking()).thenReturn(true);
    when(() => repo.getMobileTab()).thenReturn(false);
    when(() => repo.getSoundsOnDevice()).thenReturn(true);
    when(() => repo.getNotificationsOnDevice()).thenReturn(true);
  });

  Future<void> pumpCard(WidgetTester tester, {required double width, required DateTime Function() clock}) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('cs')],
        path: 'assets/translations',
        fallbackLocale: const Locale('cs'),
        startLocale: const Locale('cs'),
        useOnlyLangCode: true,
        child: Builder(
          builder: (context) => Provider<RunningTimerRepository>.value(
            value: timers,
            child: BlocProvider(
              create: (_) => PomodoroBloc(repository: repo, runningTimerRepository: timers, clock: clock, tickInterval: null)..add(const LoadPomodoro()),
              child: MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const Scaffold(
                  body: Padding(padding: EdgeInsets.all(16), child: PomodoroCard()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 50 && find.byType(PomodoroCard).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  PomodoroSession session(PomodoroStatus status, PomodoroPhase phase) => PomodoroSession(
    id: 's',
    startedAt: t0,
    phase: phase,
    status: status,
    phaseStartedAt: t0,
    phaseDurationSeconds: 1500,
    pausedAt: status == PomodoroStatus.paused ? t0.add(const Duration(minutes: 5)) : null,
    updatedAt: t0,
  );

  testWidgets('idle, running, paused, waiting and hidden states fit a narrow phone', (tester) async {
    var now = t0;
    await pumpCard(tester, width: 320, clock: () => now);
    expect(tester.takeException(), isNull);
    expect(find.text('Spustit'), findsOneWidget);
    expect(find.text('Dnes 0 🍅'), findsOneWidget);

    Future<void> show(PomodoroSession? session, DateTime at) async {
      now = at;
      when(() => repo.getSession()).thenReturn(session);
      when(() => repo.getLiveState()).thenReturn(session == null ? PomodoroLiveState.empty : PomodoroLiveState(session: session, updatedAt: session.updatedAt));
      tester.element(find.byType(PomodoroCard)).read<PomodoroBloc>().add(const LoadPomodoro());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await show(session(PomodoroStatus.running, PomodoroPhase.work), t0.add(const Duration(minutes: 10)));
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('Kolo 1/4'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);

    await show(session(PomodoroStatus.paused, PomodoroPhase.work), t0.add(const Duration(minutes: 10)));
    expect(find.text('Pozastaveno'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await show(session(PomodoroStatus.awaitingStart, PomodoroPhase.work), t0.add(const Duration(minutes: 1)));
    expect(find.text('Start práce'), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsNothing);

    await show(session(PomodoroStatus.running, PomodoroPhase.shortBreak), t0.add(const Duration(minutes: 1)));
    expect(find.text('Krátká pauza'), findsOneWidget);

    await show(null, t0);
    await tester.tap(find.text('Spustit'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Neběží žádný timer'), findsOneWidget);
    expect(find.text('Pokračovat bez timeru'), findsOneWidget);
    expect(find.text('Spustit timer'), findsOneWidget);
    await tester.tap(find.text('Zrušit'));
    await tester.pumpAndSettle();
    expect(find.text('Neběží žádný timer'), findsNothing);
    verifyNever(() => repo.setLiveState(any()));

    when(() => timers.hasRunningTimers).thenReturn(true);
    final elsewhere = session(PomodoroStatus.running, PomodoroPhase.work);
    when(() => repo.getSession()).thenReturn(elsewhere);
    when(() => repo.getLiveState()).thenReturn(PomodoroLiveState(session: elsewhere, updatedAt: t0));
    await tester.tap(find.text('Spustit'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Pomodoro už běží'), findsOneWidget);
    expect(find.textContaining('Práce, zbývá 25:00'), findsOneWidget);
    await tester.tap(find.text('Převzít'));
    await tester.pumpAndSettle();
    expect(find.text('Pomodoro už běží'), findsNothing);
    expect(find.byIcon(Icons.pause), findsOneWidget);

    when(() => repo.getShowOnTimeTracking()).thenReturn(false);
    await show(null, t0);
    expect(find.text('Spustit'), findsNothing);
  });
}
