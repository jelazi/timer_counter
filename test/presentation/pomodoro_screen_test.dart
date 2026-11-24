import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:timer_counter/core/services/pomodoro_engine.dart';
import 'package:timer_counter/data/models/pomodoro_session.dart';
import 'package:timer_counter/data/models/pomodoro_settings.dart';
import 'package:timer_counter/data/repositories/pomodoro_repository.dart';
import 'package:timer_counter/data/repositories/running_timer_repository.dart';
import 'package:timer_counter/presentation/blocs/pomodoro/pomodoro_bloc.dart';
import 'package:timer_counter/presentation/blocs/pomodoro/pomodoro_event.dart';
import 'package:timer_counter/presentation/screens/pomodoro_screen.dart';

class _MockRunningTimers extends Mock implements RunningTimerRepository {}

class _MockPomodoroRepository extends Mock implements PomodoroRepository {}

void main() {
  setUpAll(() async {
    registerFallbackValue(PomodoroSessionRecord(id: '', startedAt: DateTime(2026), endedAt: DateTime(2026), endReason: PomodoroEndReason.manual));
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('running session, summaries and a history with delete and undo fit a narrow phone', (tester) async {
    final now = DateTime(2026, 11, 24, 15);
    const settings = PomodoroSettings();
    final running = PomodoroEngine.start(id: 'live', settings: settings, now: now.subtract(const Duration(minutes: 10)), startDevice: 'macOS');
    var records = <PomodoroSessionRecord>[
      PomodoroSessionRecord(
        id: 'r1',
        startedAt: DateTime(2026, 11, 24, 9),
        endedAt: DateTime(2026, 11, 24, 10, 47),
        endReason: PomodoroEndReason.inactivity,
        completedPomodoros: 3,
        workSeconds: 4500,
        breakSeconds: 1920,
        pausedSeconds: 300,
        waitingSeconds: 120,
        startDevice: 'iOS',
      ),
      PomodoroSessionRecord(
        id: 'r2',
        startedAt: DateTime(2026, 11, 23, 13),
        endedAt: DateTime(2026, 11, 23, 14),
        endReason: PomodoroEndReason.manual,
        completedPomodoros: 2,
        workSeconds: 3000,
      ),
    ];

    final repo = _MockPomodoroRepository();
    when(() => repo.getSettings()).thenReturn(settings);
    when(() => repo.getSession()).thenReturn(running);
    when(() => repo.getLiveState()).thenReturn(PomodoroLiveState(session: running, updatedAt: running.updatedAt));
    when(() => repo.getRecords()).thenAnswer((_) => records);
    when(() => repo.getShowOnTimeTracking()).thenReturn(true);
    when(() => repo.getMobileTab()).thenReturn(false);
    when(() => repo.getSoundsOnDevice()).thenReturn(true);
    when(() => repo.getNotificationsOnDevice()).thenReturn(true);
    when(() => repo.deleteRecord(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      records = records.where((r) => r.id != id).toList();
    });
    final timers = _MockRunningTimers();
    when(() => timers.hasRunningTimers).thenReturn(true);

    tester.view.physicalSize = const Size(320, 1600);
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
              create: (_) => PomodoroBloc(repository: repo, runningTimerRepository: timers, clock: () => now, tickInterval: null)..add(const LoadPomodoro()),
              child: MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: const PomodoroScreen(standalone: true),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 50 && find.byType(PomodoroScreen).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('Dnes'), findsOneWidget);
    expect(find.text('Tento týden'), findsOneWidget);
    expect(find.text('3 🍅'), findsOneWidget);
    expect(find.text('5 🍅'), findsOneWidget);
    expect(find.text('09:00 – 10:47 · 3 🍅'), findsOneWidget);
    expect(find.textContaining('ukončeno neaktivitou'), findsOneWidget);
    expect(find.textContaining('pozastaveno 5m'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Sezení smazáno'), findsOneWidget);
    expect(find.text('09:00 – 10:47 · 3 🍅'), findsNothing);
    verify(() => repo.deleteRecord('r1')).called(1);

    when(() => repo.addRecord(any())).thenAnswer((invocation) async {
      records = [...records, invocation.positionalArguments.first as PomodoroSessionRecord];
    });
    await tester.tap(find.text('Zpět'));
    await tester.pumpAndSettle();
    expect(find.text('09:00 – 10:47 · 3 🍅'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
