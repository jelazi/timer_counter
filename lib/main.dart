import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/system_tray_service.dart';
import 'core/constants/app_constants.dart';
import 'data/models/category_model.dart';
import 'data/models/monthly_hours_target_model.dart';
import 'data/models/project_model.dart';
import 'data/models/running_timer_model.dart';
import 'data/models/task_model.dart';
import 'data/models/time_entry_model.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/monthly_hours_target_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/running_timer_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/repositories/time_entry_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Use bundled fonts — don't fetch from network
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize Hive
  await Hive.initFlutter();

  // Register Hive Adapters
  Hive.registerAdapter(CategoryModelAdapter());
  Hive.registerAdapter(ProjectModelAdapter());
  Hive.registerAdapter(TaskModelAdapter());
  Hive.registerAdapter(TimeEntryModelAdapter());
  Hive.registerAdapter(RunningTimerModelAdapter());
  Hive.registerAdapter(MonthlyHoursTargetModelAdapter());

  // Create & Initialize Repositories
  final categoryRepository = CategoryRepository();
  await categoryRepository.init();
  final projectRepository = ProjectRepository();
  await projectRepository.init();
  final taskRepository = TaskRepository();
  await taskRepository.init();
  final timeEntryRepository = TimeEntryRepository();
  await timeEntryRepository.init();
  final runningTimerRepository = RunningTimerRepository();
  await runningTimerRepository.init();
  final settingsRepository = SettingsRepository();
  await settingsRepository.init();
  final monthlyHoursTargetRepository = MonthlyHoursTargetRepository();
  await monthlyHoursTargetRepository.init();

  // Initialize Window Manager (Desktop)
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();

    final windowOptions = WindowOptions(
      size: Size(AppConstants.defaultWindowWidth, AppConstants.defaultWindowHeight),
      minimumSize: Size(AppConstants.minWindowWidth, AppConstants.minWindowHeight),
      center: true,
      backgroundColor: Colors.transparent,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Timer Counter',
    );

    // Prevent close BEFORE showing — ensures X hides to tray
    await windowManager.setPreventClose(true);

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // Setup launch at startup
    launchAtStartup.setup(appName: 'Timer Counter', appPath: Platform.resolvedExecutable);
  }

  // System Tray
  final systemTrayService = SystemTrayService();
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await systemTrayService.initialize();
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('cs')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: TymeApp(
        categoryRepository: categoryRepository,
        projectRepository: projectRepository,
        taskRepository: taskRepository,
        timeEntryRepository: timeEntryRepository,
        runningTimerRepository: runningTimerRepository,
        settingsRepository: settingsRepository,
        monthlyHoursTargetRepository: monthlyHoursTargetRepository,
        systemTrayService: systemTrayService,
      ),
    ),
  );
}
