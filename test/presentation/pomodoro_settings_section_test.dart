import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timer_counter/data/models/pomodoro_session.dart';
import 'package:timer_counter/data/models/pomodoro_settings.dart';
import 'package:timer_counter/data/repositories/pomodoro_repository.dart';
import 'package:timer_counter/data/repositories/running_timer_repository.dart';
import 'package:timer_counter/presentation/blocs/pomodoro/pomodoro_bloc.dart';
import 'package:timer_counter/presentation/blocs/pomodoro/pomodoro_event.dart';
import 'package:timer_counter/presentation/widgets/pomodoro_settings_section.dart';

class _MockRunningTimers extends Mock implements RunningTimerRepository {}

class _MockPomodoroRepository extends Mock implements PomodoroRepository {}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (call) async => call.method == 'getAll' ? <String, Object>{} : true,
    );
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('the pomodoro settings with all sound options fit a narrow phone', (tester) async {
    final repo = _MockPomodoroRepository();
    when(() => repo.getSettings()).thenReturn(const PomodoroSettings(soundWorkEnd: 'triple_beep', soundCycleDone: 'soft_gong'));
    when(() => repo.getSession()).thenReturn(null);
    when(() => repo.getLiveState()).thenReturn(PomodoroLiveState.empty);
    when(() => repo.getRecords()).thenReturn(const []);
    when(() => repo.getShowOnTimeTracking()).thenReturn(true);
    when(() => repo.getMobileTab()).thenReturn(false);
    when(() => repo.getSoundsOnDevice()).thenReturn(true);
    when(() => repo.getNotificationsOnDevice()).thenReturn(true);
    final timers = _MockRunningTimers();
    when(() => timers.hasRunningTimers).thenReturn(false);

    tester.view.physicalSize = const Size(320, 3000);
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
          builder: (context) => BlocProvider(
            create: (_) => PomodoroBloc(repository: repo, runningTimerRepository: timers, tickInterval: null)..add(const LoadPomodoro()),
            child: MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: const Scaffold(
                body: SingleChildScrollView(padding: EdgeInsets.all(16), child: PomodoroSettingsSection()),
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 50 && find.byType(PomodoroSettingsSection).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Konec dlouhé pauzy'), findsOneWidget);
    expect(find.text('Jemný gong'), findsOneWidget);
    expect(find.text('Trojité pípnutí'), findsOneWidget);
    expect(find.text('Varování před koncem fáze'), findsOneWidget);
  });
}
