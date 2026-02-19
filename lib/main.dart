import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/desktop_window_handler.dart';
import 'app/system_tray_service.dart';
import 'core/constants/app_constants.dart';
import 'core/services/firebase_sync_service_v2.dart';
import 'core/services/work_reminder_service.dart';
import 'core/utils/platform_utils.dart';
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
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initializeDateFormatting();

  // Use bundled fonts — don't fetch from network
  GoogleFonts.config.allowRuntimeFetching = false;

  // ── Firebase ────────────────────────────────────────────────────────────
  bool firebaseAvailable = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseAvailable = true;
    debugPrint('[main] Firebase initialized successfully');
  } catch (e) {
    debugPrint('[main] Firebase not available: $e');
  }

  // ── Hive ────────────────────────────────────────────────────────────────
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

  // ── Firebase Sync Service ──────────────────────────────────────────────
  FirebaseSyncService? firebaseSyncService;
  if (firebaseAvailable) {
    firebaseSyncService = FirebaseSyncService(
      categoryRepo: categoryRepository,
      projectRepo: projectRepository,
      taskRepo: taskRepository,
      timeEntryRepo: timeEntryRepository,
      runningTimerRepo: runningTimerRepository,
      monthlyTargetRepo: monthlyHoursTargetRepository,
      settingsRepo: settingsRepository,
    );
    // Auto-start listeners if already signed in
    if (firebaseSyncService.isSignedIn) {
      firebaseSyncService.startListeners();
    }
  }

  // ── Desktop Window Manager & System Tray ───────────────────────────────
  SystemTrayService? systemTrayService;
  if (PlatformUtils.isDesktop) {
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
    String appPath = Platform.resolvedExecutable;
    // On macOS, use the .app bundle path instead of the inner executable
    if (Platform.isMacOS) {
      final contentsIndex = appPath.indexOf('/Contents/');
      if (contentsIndex != -1) {
        appPath = appPath.substring(0, contentsIndex);
      }
    }
    launchAtStartup.setup(appName: 'Timer Counter', appPath: appPath);

    // System Tray
    systemTrayService = SystemTrayService();
    await systemTrayService.initialize();

    // Desktop window handler (close-to-tray, minimize-to-tray)
    DesktopWindowHandler(settingsRepo: settingsRepository);
  }

  // ── Work Reminder Notifications ────────────────────────────────────────
  if (Platform.isMacOS) {
    final workReminderService = WorkReminderService(settingsRepo: settingsRepository, timerRepo: runningTimerRepository);
    workReminderService.start();
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
        firebaseSyncService: firebaseSyncService,
      ),
    ),
  );
}
