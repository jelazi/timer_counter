import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'app/desktop_window_handler.dart';
import 'app/system_tray_service.dart';
import 'core/constants/app_constants.dart';
import 'core/services/pocketbase_config.dart';
import 'core/services/pocketbase_sync_service.dart';
import 'core/services/work_reminder_service.dart';
import 'core/utils/platform_utils.dart';
import 'data/models/category_model.dart';
import 'data/models/monthly_hours_target_model.dart';
import 'data/models/project_model.dart';
import 'data/models/running_timer_model.dart';
import 'data/models/standalone_invoice_model.dart';
import 'data/models/task_model.dart';
import 'data/models/time_entry_model.dart';
import 'data/repositories/category_repository.dart';
import 'data/repositories/monthly_hours_target_repository.dart';
import 'data/repositories/project_repository.dart';
import 'data/repositories/running_timer_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/standalone_invoice_repository.dart';
import 'data/repositories/task_repository.dart';
import 'data/repositories/time_entry_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await initializeDateFormatting();

  // Force portrait orientation on mobile devices.
  if (PlatformUtils.isMobile) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  // Use bundled fonts — don't fetch from network.
  GoogleFonts.config.allowRuntimeFetching = false;

  // ── Hive ────────────────────────────────────────────────────────────────
  await Hive.initFlutter('timer_counter');

  // Register Hive Adapters
  Hive.registerAdapter(CategoryModelAdapter());
  Hive.registerAdapter(ProjectModelAdapter());
  Hive.registerAdapter(TaskModelAdapter());
  Hive.registerAdapter(TimeEntryModelAdapter());
  Hive.registerAdapter(RunningTimerModelAdapter());
  Hive.registerAdapter(MonthlyHoursTargetModelAdapter());
  Hive.registerAdapter(InvoiceLineItemAdapter());
  Hive.registerAdapter(StandaloneInvoiceModelAdapter());

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
  final standaloneInvoiceRepository = StandaloneInvoiceRepository();
  await standaloneInvoiceRepository.init();

  // ── PocketBase Sync Service ────────────────────────────────────────────
  // Desktop/mobile: try to auto sign-in from bundled config / settings override.
  // Web: build the service without credentials — user signs in via LoginScreen.
  final pocketBaseSyncService = await _initPocketBaseSyncService(
    categoryRepository: categoryRepository,
    projectRepository: projectRepository,
    taskRepository: taskRepository,
    timeEntryRepository: timeEntryRepository,
    runningTimerRepository: runningTimerRepository,
    monthlyHoursTargetRepository: monthlyHoursTargetRepository,
    settingsRepository: settingsRepository,
  );

  // ── Desktop Window Manager & System Tray ───────────────────────────────
  SystemTrayService? systemTrayService;
  if (PlatformUtils.isDesktop) {
    systemTrayService = await _initDesktopShell(settingsRepository: settingsRepository);
  }

  // ── Work Reminder Notifications (macOS only) ───────────────────────────
  if (!kIsWeb && Platform.isMacOS) {
    final workReminderService = WorkReminderService(settingsRepo: settingsRepository, timerRepo: runningTimerRepository, timeEntryRepo: timeEntryRepository);
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
        standaloneInvoiceRepository: standaloneInvoiceRepository,
        systemTrayService: systemTrayService,
        pocketBaseSyncService: pocketBaseSyncService,
      ),
    ),
  );
}

/// Build the PocketBase sync service and, on non-web platforms, attempt an
/// automatic sign-in using the bundled config or settings override.
///
/// On web, only the server URL is resolved (via `--dart-define` or bundled
/// config); credentials must always be entered by the user on the login screen.
/// Returns `null` if no PocketBase URL is configured at all.
Future<PocketBaseSyncService?> _initPocketBaseSyncService({
  required CategoryRepository categoryRepository,
  required ProjectRepository projectRepository,
  required TaskRepository taskRepository,
  required TimeEntryRepository timeEntryRepository,
  required RunningTimerRepository runningTimerRepository,
  required MonthlyHoursTargetRepository monthlyHoursTargetRepository,
  required SettingsRepository settingsRepository,
}) async {
  PocketBaseSyncService? service;

  if (kIsWeb) {
    final url = await PocketBaseConfig.resolveServerUrl(settingsRepository);
    if (url == null) {
      debugPrint('[PocketBase] No server URL configured for web build. Pass --dart-define=POCKETBASE_URL=...');
      return null;
    }
    service = PocketBaseSyncService(
      serverUrl: url,
      categoryRepo: categoryRepository,
      projectRepo: projectRepository,
      taskRepo: taskRepository,
      timeEntryRepo: timeEntryRepository,
      runningTimerRepo: runningTimerRepository,
      monthlyTargetRepo: monthlyHoursTargetRepository,
      settingsRepo: settingsRepository,
    );
    // If a token was persisted (e.g. AsyncAuthStore in the future), listeners
    // could be started here. For now we always require explicit login on web.
    return service;
  }

  final pbConfig = await PocketBaseConfig.loadEffective(settingsRepository);
  if (pbConfig == null) return null;

  service = PocketBaseSyncService(
    serverUrl: pbConfig.url,
    categoryRepo: categoryRepository,
    projectRepo: projectRepository,
    taskRepo: taskRepository,
    timeEntryRepo: timeEntryRepository,
    runningTimerRepo: runningTimerRepository,
    monthlyTargetRepo: monthlyHoursTargetRepository,
    settingsRepo: settingsRepository,
  );

  final error = await service.signIn(pbConfig.email, pbConfig.password);
  if (error == null) {
    await service.startListeners();
    final (action, result) = await service.smartFirstSync();
    debugPrint('[PocketBase] Smart first sync: $action, ${result?.total ?? 0} items');
  } else {
    debugPrint('[PocketBase] Auto sign-in failed: $error');
  }
  return service;
}

/// Initialize window manager, system tray, launch-at-startup, and the close-
/// to-tray handler. Only called on desktop platforms.
Future<SystemTrayService> _initDesktopShell({required SettingsRepository settingsRepository}) async {
  await windowManager.ensureInitialized();

  final windowOptions = WindowOptions(
    size: Size(AppConstants.defaultWindowWidth, AppConstants.defaultWindowHeight),
    minimumSize: Size(AppConstants.minWindowWidth, AppConstants.minWindowHeight),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: Platform.isWindows ? TitleBarStyle.normal : TitleBarStyle.hidden,
    title: 'Timer Counter',
  );

  // Prevent close BEFORE showing — ensures X hides to tray.
  await windowManager.setPreventClose(true);

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Setup launch at startup.
  String appPath = Platform.resolvedExecutable;
  // On macOS, use the .app bundle path instead of the inner executable.
  if (Platform.isMacOS) {
    final contentsIndex = appPath.indexOf('/Contents/');
    if (contentsIndex != -1) {
      appPath = appPath.substring(0, contentsIndex);
    }
  }
  launchAtStartup.setup(appName: 'Timer Counter', appPath: appPath);

  // System Tray.
  final systemTrayService = SystemTrayService();
  await systemTrayService.initialize();

  // Desktop window handler (close-to-tray, minimize-to-tray).
  DesktopWindowHandler(settingsRepo: settingsRepository);

  return systemTrayService;
}
