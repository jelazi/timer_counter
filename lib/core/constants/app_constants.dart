class AppConstants {
  AppConstants._();

  static const String appName = 'Timer Counter';
  static const String appVersion = '1.0.0';

  // Hive Box Names
  static const String categoriesBox = 'categories';
  static const String projectsBox = 'projects';
  static const String tasksBox = 'tasks';
  static const String timeEntriesBox = 'time_entries';
  static const String settingsBox = 'settings';
  static const String runningTimersBox = 'running_timers';
  static const String monthlyHoursTargetsBox = 'monthly_hours_targets';

  // Settings Keys
  static const String themeMode = 'theme_mode';
  static const String language = 'language';
  static const String timeFormat = 'time_format';
  static const String currency = 'currency';
  static const String dailyWorkingHours = 'daily_working_hours';
  static const String weeklyWorkingDays = 'weekly_working_days';
  static const String simultaneousTimers = 'simultaneous_timers';
  static const String showSeconds = 'show_seconds';
  static const String roundTime = 'round_time';
  static const String roundToMinutes = 'round_to_minutes';
  static const String launchAtStartup = 'launch_at_startup';
  static const String minimizeToTray = 'minimize_to_tray';
  static const String remindStart = 'remind_start';
  static const String remindStop = 'remind_stop';
  static const String remindBreak = 'remind_break';
  static const String lastProjectId = 'last_project_id';
  static const String lastTaskId = 'last_task_id';
  static const String recentTasks = 'recent_tasks';
  static const String allowOverlapTimes = 'allow_overlap_times';

  // Invoice Settings Keys
  static const String invoiceSuppliers = 'invoice_suppliers';
  static const String invoiceCustomers = 'invoice_customers';
  static const String invoiceSelectedSupplierIndex = 'invoice_selected_supplier_index';
  static const String invoiceSelectedCustomerIndex = 'invoice_selected_customer_index';
  static const String invoiceDescription = 'invoice_description';
  static const String invoiceBankName = 'invoice_bank_name';
  static const String invoiceBankCode = 'invoice_bank_code';
  static const String invoiceSwift = 'invoice_swift';
  static const String invoiceAccountNumber = 'invoice_account_number';
  static const String invoiceIban = 'invoice_iban';
  static const String invoiceIssuerName = 'invoice_issuer_name';
  static const String invoiceIssuerEmail = 'invoice_issuer_email';
  static const String invoiceReportFilename = 'invoice_report_filename';
  static const String invoiceReportRezijniFilename = 'invoice_report_rezijni_filename';
  static const String invoiceInvoiceFilename = 'invoice_invoice_filename';

  // PDF Report Project Filter
  static const String pdfReportProjectIds = 'pdf_report_project_ids';

  // Work Schedule (per weekday)
  static const String workSchedulePrefix = 'work_schedule';

  // Firebase Sync Keys
  static const String firebaseProjectId = 'firebase_project_id';
  static const String firebaseApiKey = 'firebase_api_key';
  static const String firebaseEnabled = 'firebase_enabled';
  static const String firebaseLastSync = 'firebase_last_sync';

  // Default Values
  static const double defaultDailyWorkingHours = 8.0;
  static const int defaultWeeklyWorkingDays = 5;
  static const String defaultCurrency = 'CZK';
  static const int defaultRoundToMinutes = 5;

  // Project Colors
  static const List<int> projectColors = [
    0xFF4CAF50, // Green
    0xFF2196F3, // Blue
    0xFFF44336, // Red
    0xFFFF9800, // Orange
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFFFF5722, // Deep Orange
    0xFF607D8B, // Blue Grey
    0xFFE91E63, // Pink
    0xFF3F51B5, // Indigo
    0xFF009688, // Teal
    0xFFFFC107, // Amber
  ];

  // Window dimensions
  static const double minWindowWidth = 900;
  static const double minWindowHeight = 600;
  static const double defaultWindowWidth = 1200;
  static const double defaultWindowHeight = 800;
}
