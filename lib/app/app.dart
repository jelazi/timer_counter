import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../core/services/backup_service.dart';
import '../core/services/daily_snapshot_service.dart';
import '../core/services/deletion_journal_service.dart';
import '../core/services/pocketbase_sync_service.dart';
import '../core/services/pomodoro_alerts.dart';
import '../core/services/snapshot_diff_service.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/desktop_theme.dart';
import '../core/utils/platform_utils.dart';
import '../core/utils/time_formatter.dart';
import '../data/models/pomodoro_session.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/client_repository.dart';
import '../data/repositories/monthly_hours_target_repository.dart';
import '../data/repositories/pomodoro_repository.dart';
import '../data/repositories/project_client_repository.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/running_timer_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/standalone_invoice_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/time_entry_repository.dart';
import '../presentation/blocs/category/category_bloc.dart';
import '../presentation/blocs/category/category_event.dart';
import '../presentation/blocs/client/client_bloc.dart';
import '../presentation/blocs/client/client_event.dart';
import '../presentation/blocs/pomodoro/pomodoro_bloc.dart';
import '../presentation/blocs/pomodoro/pomodoro_event.dart';
import '../presentation/blocs/pomodoro/pomodoro_state.dart';
import '../presentation/blocs/project/project_bloc.dart';
import '../presentation/blocs/project/project_event.dart';
import '../presentation/blocs/settings/settings_bloc.dart';
import '../presentation/blocs/settings/settings_event.dart';
import '../presentation/blocs/settings/settings_state.dart';
import '../presentation/blocs/standalone_invoice/standalone_invoice_bloc.dart';
import '../presentation/blocs/standalone_invoice/standalone_invoice_event.dart';
import '../presentation/blocs/statistics/statistics_bloc.dart';
import '../presentation/blocs/task/task_bloc.dart';
import '../presentation/blocs/task/task_event.dart';
import '../presentation/blocs/timer/timer_bloc.dart';
import '../presentation/blocs/timer/timer_event.dart';
import '../presentation/blocs/timer/timer_state.dart';
import '../presentation/screens/backup_history_screen.dart';
import '../presentation/widgets/auth_gate.dart';
import '../presentation/widgets/pomodoro_card.dart';
import 'system_tray_service.dart';
import 'tray_title.dart';

class TymeApp extends StatelessWidget {
  final CategoryRepository categoryRepository;
  final ProjectRepository projectRepository;
  final TaskRepository taskRepository;
  final TimeEntryRepository timeEntryRepository;
  final RunningTimerRepository runningTimerRepository;
  final SettingsRepository settingsRepository;
  final MonthlyHoursTargetRepository monthlyHoursTargetRepository;
  final StandaloneInvoiceRepository standaloneInvoiceRepository;
  final ClientRepository clientRepository;
  final ProjectClientRepository projectClientRepository;
  final PomodoroRepository pomodoroRepository;
  final PomodoroAlerts? pomodoroAlerts;
  final SystemTrayService? systemTrayService;
  final PocketBaseSyncService? pocketBaseSyncService;
  final BackupService backupService;
  final DailySnapshotService snapshotService;
  final SnapshotDiffService snapshotDiffService;
  final DeletionJournalService deletionJournal;

  const TymeApp({
    super.key,
    required this.categoryRepository,
    required this.projectRepository,
    required this.taskRepository,
    required this.timeEntryRepository,
    required this.runningTimerRepository,
    required this.settingsRepository,
    required this.monthlyHoursTargetRepository,
    required this.standaloneInvoiceRepository,
    required this.clientRepository,
    required this.projectClientRepository,
    required this.pomodoroRepository,
    this.pomodoroAlerts,
    required this.backupService,
    required this.snapshotService,
    required this.snapshotDiffService,
    required this.deletionJournal,
    this.systemTrayService,
    this.pocketBaseSyncService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<CategoryRepository>.value(value: categoryRepository),
        Provider<ProjectRepository>.value(value: projectRepository),
        Provider<TaskRepository>.value(value: taskRepository),
        Provider<TimeEntryRepository>.value(value: timeEntryRepository),
        Provider<RunningTimerRepository>.value(value: runningTimerRepository),
        Provider<SettingsRepository>.value(value: settingsRepository),
        Provider<MonthlyHoursTargetRepository>.value(value: monthlyHoursTargetRepository),
        Provider<StandaloneInvoiceRepository>.value(value: standaloneInvoiceRepository),
        Provider<ClientRepository>.value(value: clientRepository),
        Provider<ProjectClientRepository>.value(value: projectClientRepository),
        Provider<PomodoroRepository>.value(value: pomodoroRepository),
        if (systemTrayService != null) Provider<SystemTrayService>.value(value: systemTrayService!),
        Provider<PocketBaseSyncService?>.value(value: pocketBaseSyncService),
        Provider<BackupService>.value(value: backupService),
        Provider<DailySnapshotService>.value(value: snapshotService),
        Provider<SnapshotDiffService>.value(value: snapshotDiffService),
        Provider<DeletionJournalService>.value(value: deletionJournal),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<CategoryBloc>(
            create: (context) => CategoryBloc(categoryRepository: categoryRepository, syncService: pocketBaseSyncService)..add(LoadCategories()),
          ),
          BlocProvider<ProjectBloc>(
            create: (context) =>
                ProjectBloc(projectRepository: projectRepository, taskRepository: taskRepository, timeEntryRepository: timeEntryRepository, syncService: pocketBaseSyncService)
                  ..add(const LoadProjects()),
          ),
          BlocProvider<TaskBloc>(
            create: (context) => TaskBloc(taskRepository: taskRepository, timeEntryRepository: timeEntryRepository, syncService: pocketBaseSyncService)..add(LoadAllTasks()),
          ),
          BlocProvider<TimerBloc>(
            create: (context) => TimerBloc(
              runningTimerRepository: runningTimerRepository,
              timeEntryRepository: timeEntryRepository,
              settingsRepository: settingsRepository,
              syncService: pocketBaseSyncService,
            ),
          ),
          BlocProvider<PomodoroBloc>(
            create: (context) =>
                PomodoroBloc(repository: pomodoroRepository, runningTimerRepository: runningTimerRepository, syncService: pocketBaseSyncService, alerts: pomodoroAlerts)
                  ..add(const LoadPomodoro()),
          ),
          BlocProvider<StatisticsBloc>(
            create: (context) => StatisticsBloc(timeEntryRepository: timeEntryRepository, projectRepository: projectRepository, settingsRepository: settingsRepository),
          ),
          BlocProvider<SettingsBloc>(create: (context) => SettingsBloc(settingsRepository: settingsRepository)..add(LoadSettings())),
          BlocProvider<StandaloneInvoiceBloc>(
            create: (context) => StandaloneInvoiceBloc(repository: standaloneInvoiceRepository, syncService: pocketBaseSyncService)..add(const LoadStandaloneInvoices()),
          ),
          BlocProvider<ClientBloc>(
            create: (context) => ClientBloc(
              clientRepository: clientRepository,
              projectClientRepository: projectClientRepository,
              invoiceRepository: standaloneInvoiceRepository,
              syncService: pocketBaseSyncService,
            )..add(const LoadClients()),
          ),
        ],
        child: _AppWithTheme(
          settingsRepository: settingsRepository,
          systemTrayService: systemTrayService,
          pocketBaseSyncService: pocketBaseSyncService,
          snapshotService: snapshotService,
        ),
      ),
    );
  }
}

class _AppWithTheme extends StatefulWidget {
  final SettingsRepository settingsRepository;
  final SystemTrayService? systemTrayService;
  final PocketBaseSyncService? pocketBaseSyncService;
  final DailySnapshotService snapshotService;

  const _AppWithTheme({required this.settingsRepository, required this.snapshotService, this.systemTrayService, this.pocketBaseSyncService});

  @override
  State<_AppWithTheme> createState() => _AppWithThemeState();
}

class _AppWithThemeState extends State<_AppWithTheme> with WidgetsBindingObserver {
  /// Lets the guard banner reach a Scaffold no matter which screen is on top.
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();

  StreamSubscription<SyncGuardReport>? _guardSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Sync refused to apply a mass deletion. Never silently swallow this — it
    // means the local and remote stores disagree about data that still exists.
    _guardSubscription = widget.pocketBaseSyncService?.onGuardTriggered.listen(_showGuardWarning);
  }

  @override
  void dispose() {
    _guardSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Mobile suspends the real-time SSE connection while backgrounded, so on
    // resume we reconnect and pull anything changed while we were away.
    if (state == AppLifecycleState.resumed) {
      _messengerKey.currentContext?.read<PomodoroBloc>().add(const LoadPomodoro());
      _resumeAndResync();
    }
  }

  /// Snapshot first, then sync — the app can run for days without restarting,
  /// so this is the only chance to capture a clean state before a resync that
  /// might reconcile records away.
  Future<void> _resumeAndResync() async {
    await widget.snapshotService.takeSnapshotIfDue();
    await widget.pocketBaseSyncService?.resync();
  }

  void _showGuardWarning(SyncGuardReport report) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(tr('sync.guard_blocked', namedArgs: {'count': '${report.blockedDeletions}', 'collection': report.collection})),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 10),
        persist: false,
        action: SnackBarAction(
          label: tr('sync.guard_review'),
          textColor: Colors.white,
          onPressed: () {
            final context = _messengerKey.currentContext;
            if (context != null) {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupHistoryScreen()));
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, dynamic>(
      builder: (context, state) {
        final themeMode = widget.settingsRepository.getThemeMode();
        ThemeMode mode;
        switch (themeMode) {
          case 'light':
            mode = ThemeMode.light;
            break;
          case 'dark':
            mode = ThemeMode.dark;
            break;
          default:
            mode = ThemeMode.system;
        }

        return MaterialApp(
          title: 'Timer Counter',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: _messengerKey,
          theme: PlatformUtils.isDesktop ? DesktopTheme.light : AppTheme.lightTheme,
          darkTheme: PlatformUtils.isDesktop ? DesktopTheme.dark : AppTheme.darkTheme,
          themeMode: mode,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: MultiBlocListener(
            listeners: [
              BlocListener<TimerBloc, TimerState>(listener: (context, _) => _updateSystemTray(context)),
              BlocListener<PomodoroBloc, PomodoroState>(listener: (context, _) => _updateSystemTray(context)),
              BlocListener<SettingsBloc, SettingsState>(
                listenWhen: (previous, current) => previous.trayDisplay != current.trayDisplay,
                listener: (context, _) => _updateSystemTray(context),
              ),
            ],
            child: AuthGate(syncService: widget.pocketBaseSyncService),
          ),
        );
      },
    );
  }

  void _updateSystemTray(BuildContext context) {
    final trayService = widget.systemTrayService;
    if (!PlatformUtils.isDesktop || trayService == null) return;
    final projectRepo = context.read<ProjectRepository>();
    final taskRepo = context.read<TaskRepository>();
    final settingsRepo = context.read<SettingsRepository>();
    final timerBloc = context.read<TimerBloc>();
    final pomodoroBloc = context.read<PomodoroBloc>();
    final display = context.read<SettingsBloc>().state.trayDisplay;
    final timerState = timerBloc.state;
    final timersLoaded = timerState is TimerRunning;

    final projectInfos = projectRepo.getActive().map((p) {
      final tasks = taskRepo.getByProject(p.id);
      return TrayProjectInfo(
        id: p.id,
        name: p.name,
        tasks: tasks.map((t) => TrayTaskInfo(id: t.id, name: t.name)).toList(),
      );
    }).toList();

    final runningTimerInfos = !timersLoaded
        ? <TrayRunningTimerInfo>[]
        : timerState.runningTimers.map((t) {
            final project = projectRepo.getById(t.projectId);
            final task = taskRepo.getById(t.taskId);
            return TrayRunningTimerInfo(
              id: t.id,
              projectId: t.projectId,
              taskId: t.taskId,
              projectName: project?.name ?? 'Unknown',
              taskName: task?.name ?? 'Unknown',
              elapsed: TimeFormatter.formatDuration(t.elapsedSeconds, showSeconds: false),
            );
          }).toList();
    final first = runningTimerInfos.isEmpty ? null : runningTimerInfos.first;
    final totalFormatted = timersLoaded ? TimeFormatter.formatDuration(timerState.totalTodaySeconds, showSeconds: false) : null;

    var tooltip = 'Timer Counter';
    if (timersLoaded) {
      if (first != null) tooltip = '${first.projectName} / ${first.taskName} — ${first.elapsed}';
      tooltip += ' | Today: $totalFormatted';
    }
    trayService.updateTooltip(tooltip);

    final pomodoroState = pomodoroBloc.state;
    final session = pomodoroState.session;
    final rounds = pomodoroState.settings.roundsBeforeLongBreak;
    final pomodoroInfo = session == null
        ? null
        : TrayPomodoroInfo(
            isWork: session.phase == PomodoroPhase.work,
            isPaused: session.isPaused,
            isAwaitingStart: session.isAwaitingStart,
            countdown: formatPomodoroCountdown(session.remainingSeconds(DateTime.now())),
            round: session.round(rounds),
            rounds: rounds,
            phaseLabel: pomodoroPhaseLabel(session.phase),
          );

    trayService.updateTitle(
      TrayTitle.build(display: display, timersLoaded: timersLoaded, pomodoro: pomodoroInfo, taskName: first?.taskName, elapsed: first?.elapsed, todayTotal: totalFormatted),
    );

    final recentTaskInfos = <TrayRecentTaskInfo>[];
    for (final pair in settingsRepo.getRecentTasks()) {
      final p = projectRepo.getById(pair['projectId'] ?? '');
      final t = taskRepo.getById(pair['taskId'] ?? '');
      if (p != null && t != null && !p.isArchived) {
        recentTaskInfos.add(TrayRecentTaskInfo(projectId: p.id, taskId: t.id, projectName: p.name, taskName: t.name, projectColor: p.colorValue));
      }
    }

    void startTimer(String projectId, String taskId) {
      settingsRepo.addRecentTask(projectId, taskId);
      timerBloc.add(StartTimer(projectId: projectId, taskId: taskId));
    }

    trayService.updateMenu(
      runningTimers: runningTimerInfos,
      recentTasks: recentTaskInfos,
      projects: projectInfos,
      onStopAll: () => timerBloc.add(const StopAllTimers()),
      onStopTimer: (timerId) => timerBloc.add(StopTimer(timerId)),
      onStartTimer: startTimer,
      display: display,
      pomodoro: _trayPomodoroMenu(pomodoroBloc, pomodoroInfo, startTimer),
    );
  }

  TrayPomodoroMenu _trayPomodoroMenu(PomodoroBloc bloc, TrayPomodoroInfo? info, TrayStartTimerCallback startTimer) {
    final withTimerLabel = '🍅 ${tr('pomodoro.tray_with_timer')}';
    if (info == null) {
      return TrayPomodoroMenu(
        actions: [TrayMenuAction('🍅 ${tr('pomodoro.tray_start')}', () => bloc.add(const StartPomodoro(notifyIfNoTimer: true)))],
        withTimerLabel: withTimerLabel,
        onStartWithTimer: (projectId, taskId, timerRunning) {
          if (!timerRunning) startTimer(projectId, taskId);
          bloc.add(const StartPomodoro(timerStarted: true));
        },
      );
    }
    final marker = info.isPaused ? ' ⏸' : (info.isAwaitingStart ? ' ▶' : '');
    return TrayPomodoroMenu(
      withTimerLabel: withTimerLabel,
      actions: [
        TrayMenuAction('${info.icon} ${info.phaseLabel} ${info.countdown} (${info.round}/${info.rounds})$marker'),
        if (info.isAwaitingStart)
          TrayMenuAction('▶ ${tr(info.isWork ? 'pomodoro.start_work' : 'pomodoro.start_break')}', () => bloc.add(const StartPendingPomodoroPhase()))
        else ...[
          info.isPaused
              ? TrayMenuAction('▶ ${tr('pomodoro.resume')}', () => bloc.add(const ResumePomodoro()))
              : TrayMenuAction('⏸ ${tr('pomodoro.pause')}', () => bloc.add(const PausePomodoro())),
          TrayMenuAction('⏭ ${tr('pomodoro.skip')}', () => bloc.add(const SkipPomodoroPhase())),
        ],
        TrayMenuAction('⏹ ${tr('pomodoro.stop')}', () => bloc.add(const StopPomodoro())),
      ],
    );
  }
}
