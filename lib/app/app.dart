import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/time_formatter.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/monthly_hours_target_repository.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/running_timer_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/time_entry_repository.dart';
import '../presentation/blocs/category/category_bloc.dart';
import '../presentation/blocs/category/category_event.dart';
import '../presentation/blocs/project/project_bloc.dart';
import '../presentation/blocs/project/project_event.dart';
import '../presentation/blocs/settings/settings_bloc.dart';
import '../presentation/blocs/settings/settings_event.dart';
import '../presentation/blocs/statistics/statistics_bloc.dart';
import '../presentation/blocs/task/task_bloc.dart';
import '../presentation/blocs/task/task_event.dart';
import '../presentation/blocs/timer/timer_bloc.dart';
import '../presentation/blocs/timer/timer_event.dart';
import '../presentation/blocs/timer/timer_state.dart';
import '../presentation/screens/home_screen.dart';
import 'system_tray_service.dart';

class TymeApp extends StatelessWidget {
  final CategoryRepository categoryRepository;
  final ProjectRepository projectRepository;
  final TaskRepository taskRepository;
  final TimeEntryRepository timeEntryRepository;
  final RunningTimerRepository runningTimerRepository;
  final SettingsRepository settingsRepository;
  final MonthlyHoursTargetRepository monthlyHoursTargetRepository;
  final SystemTrayService systemTrayService;

  const TymeApp({
    super.key,
    required this.categoryRepository,
    required this.projectRepository,
    required this.taskRepository,
    required this.timeEntryRepository,
    required this.runningTimerRepository,
    required this.settingsRepository,
    required this.monthlyHoursTargetRepository,
    required this.systemTrayService,
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
        Provider<SystemTrayService>.value(value: systemTrayService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<CategoryBloc>(create: (context) => CategoryBloc(categoryRepository: categoryRepository)..add(LoadCategories())),
          BlocProvider<ProjectBloc>(
            create: (context) => ProjectBloc(projectRepository: projectRepository, taskRepository: taskRepository, timeEntryRepository: timeEntryRepository)..add(LoadProjects()),
          ),
          BlocProvider<TaskBloc>(
            create: (context) => TaskBloc(taskRepository: taskRepository, timeEntryRepository: timeEntryRepository)..add(LoadAllTasks()),
          ),
          BlocProvider<TimerBloc>(
            create: (context) =>
                TimerBloc(runningTimerRepository: runningTimerRepository, timeEntryRepository: timeEntryRepository, settingsRepository: settingsRepository)
                  ..add(LoadRunningTimers()),
          ),
          BlocProvider<StatisticsBloc>(
            create: (context) => StatisticsBloc(timeEntryRepository: timeEntryRepository, projectRepository: projectRepository, settingsRepository: settingsRepository),
          ),
          BlocProvider<SettingsBloc>(create: (context) => SettingsBloc(settingsRepository: settingsRepository)..add(LoadSettings())),
        ],
        child: _AppWithTheme(settingsRepository: settingsRepository),
      ),
    );
  }
}

class _AppWithTheme extends StatelessWidget {
  final SettingsRepository settingsRepository;

  const _AppWithTheme({required this.settingsRepository});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, dynamic>(
      builder: (context, state) {
        final themeMode = settingsRepository.getThemeMode();
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
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: BlocListener<TimerBloc, TimerState>(
            listener: (context, timerState) {
              _updateSystemTray(context, timerState);
            },
            child: const HomeScreen(),
          ),
        );
      },
    );
  }

  void _updateSystemTray(BuildContext context, TimerState timerState) {
    final trayService = context.read<SystemTrayService>();
    final projectRepo = context.read<ProjectRepository>();
    final taskRepo = context.read<TaskRepository>();

    // Build project list for quick-start
    final activeProjects = projectRepo.getActive();
    final projectInfos = activeProjects.map((p) {
      final tasks = taskRepo.getByProject(p.id);
      return TrayProjectInfo(
        id: p.id,
        name: p.name,
        tasks: tasks.map((t) => TrayTaskInfo(id: t.id, name: t.name)).toList(),
      );
    }).toList();

    if (timerState is TimerRunning) {
      // Build running timer info
      final runningTimerInfos = timerState.runningTimers.map((t) {
        final project = projectRepo.getById(t.projectId);
        final task = taskRepo.getById(t.taskId);
        return TrayRunningTimerInfo(
          id: t.id,
          projectName: project?.name ?? 'Unknown',
          taskName: task?.name ?? 'Unknown',
          elapsed: TimeFormatter.formatDuration(t.elapsedSeconds, showSeconds: false),
        );
      }).toList();

      // Update tooltip — show current task + running time + total today
      final totalFormatted = TimeFormatter.formatDuration(timerState.totalTodaySeconds, showSeconds: false);
      String tooltip = 'Timer Counter';
      if (runningTimerInfos.isNotEmpty) {
        final first = runningTimerInfos.first;
        tooltip = '${first.projectName} / ${first.taskName} — ${first.elapsed}';
      }
      tooltip += ' | Today: $totalFormatted';
      trayService.updateTooltip(tooltip);

      // Update title — show task name + elapsed | total today
      if (runningTimerInfos.isNotEmpty) {
        final first = runningTimerInfos.first;
        trayService.updateTitle('${first.taskName} ${first.elapsed} | $totalFormatted');
      } else {
        trayService.updateTitle('0:00 | $totalFormatted');
      }

      // Update menu
      trayService.updateMenu(
        runningTimers: runningTimerInfos,
        projects: projectInfos,
        onStopAll: () => context.read<TimerBloc>().add(const StopAllTimers()),
        onStopTimer: (timerId) => context.read<TimerBloc>().add(StopTimer(timerId)),
        onStartTimer: (projectId, taskId) => context.read<TimerBloc>().add(StartTimer(projectId: projectId, taskId: taskId)),
      );
    } else {
      // No timer running — show 0:00 and empty total
      trayService.updateTooltip('Timer Counter');
      trayService.updateTitle('0:00');

      // Update menu with no running timers
      trayService.updateMenu(
        runningTimers: [],
        projects: projectInfos,
        onStopAll: () {},
        onStopTimer: (_) {},
        onStartTimer: (projectId, taskId) => context.read<TimerBloc>().add(StartTimer(projectId: projectId, taskId: taskId)),
      );
    }
  }
}
