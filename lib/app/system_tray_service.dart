import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/dock_service.dart';
import '../data/models/tray_display_settings.dart';

/// Callback signature for starting a timer from the tray menu.
typedef TrayStartTimerCallback = void Function(String projectId, String taskId);

/// Callback signature for stopping a timer from the tray menu.
typedef TrayStopTimerCallback = void Function(String timerId);

/// Callback for "start a pomodoro together with this task's timer";
/// [timerRunning] when that timer already runs.
typedef TrayStartPomodoroWithTimerCallback = void Function(String projectId, String taskId, bool timerRunning);

class TrayMenuAction {
  final String label;
  final VoidCallback? onClicked;

  const TrayMenuAction(this.label, [this.onClicked]);
}

/// The pomodoro block of the tray menu, labels already translated.
class TrayPomodoroMenu {
  final List<TrayMenuAction> actions;
  final String withTimerLabel;

  /// Null while a session runs: a second one cannot be started.
  final TrayStartPomodoroWithTimerCallback? onStartWithTimer;

  const TrayPomodoroMenu({required this.actions, required this.withTimerLabel, this.onStartWithTimer});
}

/// Info about a project+tasks for the tray menu.
class TrayProjectInfo {
  final String id;
  final String name;
  final List<TrayTaskInfo> tasks;

  const TrayProjectInfo({
    required this.id,
    required this.name,
    required this.tasks,
  });
}

class TrayTaskInfo {
  final String id;
  final String name;

  const TrayTaskInfo({required this.id, required this.name});
}

/// Info about a running timer for the tray menu.
class TrayRunningTimerInfo {
  final String id;
  final String projectId;
  final String taskId;
  final String projectName;
  final String taskName;
  final String elapsed;

  const TrayRunningTimerInfo({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.projectName,
    required this.taskName,
    required this.elapsed,
  });
}

/// Info about a recently used project+task for the tray menu.
class TrayRecentTaskInfo {
  final String projectId;
  final String taskId;
  final String projectName;
  final String taskName;
  final int projectColor;

  const TrayRecentTaskInfo({
    required this.projectId,
    required this.taskId,
    required this.projectName,
    required this.taskName,
    required this.projectColor,
  });
}

class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;
  String? _lastTitle;
  String? _lastTooltip;
  String? _lastMenuSignature;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _systemTray.initSystemTray(
        title: 'Timer Counter',
        iconPath: _resolveIconPath(),
        toolTip: 'Timer Counter - Time Tracking',
      );

      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(label: 'Show', onClicked: (_) => _showWindow()),
        MenuSeparator(),
        MenuItemLabel(label: 'Quit', onClicked: (_) => _quitApp()),
      ]);

      await _systemTray.setContextMenu(menu);

      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          _systemTray.popUpContextMenu();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      _isInitialized = true;
    } catch (error, stackTrace) {
      debugPrint('[SystemTray] Initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _resolveIconPath() {
    final cwd = Directory.current.path;
    final executableDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[];

    if (Platform.isWindows) {
      candidates
        ..add(
          _join(executableDir, [
            'data',
            'flutter_assets',
            'assets',
            'icons',
            'app_icon.ico',
          ]),
        )
        ..add(_join(executableDir, ['assets', 'icons', 'app_icon.ico']))
        ..add(_join(cwd, ['assets', 'icons', 'app_icon.ico']))
        ..add(_join(cwd, ['windows', 'runner', 'resources', 'app_icon.ico']));
    }

    candidates
      ..add(
        _join(executableDir, [
          'data',
          'flutter_assets',
          'assets',
          'icons',
          'app_icon.png',
        ]),
      )
      ..add(_join(executableDir, ['assets', 'icons', 'app_icon.png']))
      ..add(_join(cwd, ['assets', 'icons', 'app_icon.png']))
      ..add(_join(cwd, ['assets', 'icons', 'app_icon.jpg']));

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    // Last fallback keeps previous behavior for environments with custom layout.
    return Platform.isWindows
        ? 'windows/runner/resources/app_icon.ico'
        : 'assets/icons/app_icon.png';
  }

  String _join(String root, List<String> parts) {
    return [root, ...parts].join(Platform.pathSeparator);
  }

  Future<void> _showWindow() async {
    await DockService.showInDock();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quitApp() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  Future<void> updateTooltip(String tooltip) async {
    if (!_isInitialized || tooltip == _lastTooltip) return;
    _lastTooltip = tooltip;
    await _systemTray.setToolTip(tooltip);
  }

  Future<void> updateTitle(String title) async {
    if (!_isInitialized || title == _lastTitle) return;
    _lastTitle = title;
    await _systemTray.setTitle(title);
  }

  /// Build a rich tray menu with the pomodoro, running timers, recent tasks and
  /// project/task quick-start; each block can be switched off in [display].
  Future<void> updateMenu({
    required List<TrayRunningTimerInfo> runningTimers,
    required List<TrayRecentTaskInfo> recentTasks,
    required List<TrayProjectInfo> projects,
    required VoidCallback onStopAll,
    required TrayStopTimerCallback onStopTimer,
    required TrayStartTimerCallback onStartTimer,
    TrayDisplaySettings display = const TrayDisplaySettings(),
    TrayPomodoroMenu? pomodoro,
  }) async {
    if (!_isInitialized) return;

    final menuItems = <MenuItemBase>[
      MenuItemLabel(
        label: 'Show Timer Counter',
        onClicked: (_) => _showWindow(),
      ),
      MenuSeparator(),
    ];

    final runningPairs = runningTimers
        .map((t) => '${t.projectId}:${t.taskId}')
        .toSet();

    if (pomodoro != null && display.menuPomodoro) {
      for (final action in pomodoro.actions) {
        menuItems.add(
          MenuItemLabel(
            label: action.label,
            enabled: action.onClicked != null,
            onClicked: action.onClicked == null ? null : (_) => action.onClicked!(),
          ),
        );
      }
      if (display.menuPomodoroWithTimer && pomodoro.onStartWithTimer != null && recentTasks.isNotEmpty) {
        final subMenu = SubMenu(label: pomodoro.withTimerLabel, children: []);
        for (final recent in recentTasks) {
          final isRunning = runningPairs.contains('${recent.projectId}:${recent.taskId}');
          subMenu.children.add(
            MenuItemLabel(
              label: '${recent.projectName} / ${recent.taskName}',
              onClicked: (_) => pomodoro.onStartWithTimer!(recent.projectId, recent.taskId, isRunning),
            ),
          );
        }
        menuItems.add(subMenu);
      }
      menuItems.add(MenuSeparator());
    }

    // Running timers section
    if (runningTimers.isNotEmpty && display.menuRunningTimers) {
      for (final timer in runningTimers) {
        menuItems.add(
          MenuItemLabel(
            label:
                '▶ ${timer.projectName} / ${timer.taskName}  (${timer.elapsed})',
            onClicked: (_) => onStopTimer(timer.id),
          ),
        );
      }
      menuItems.add(
        MenuItemLabel(label: 'Stop All Timers', onClicked: (_) => onStopAll()),
      );
      menuItems.add(MenuSeparator());
    }

    // Recent tasks — shown at root level for quick access
    if (recentTasks.isNotEmpty && display.menuRecentTasks) {
      for (final recent in recentTasks) {
        final isRunning = runningPairs.contains(
          '${recent.projectId}:${recent.taskId}',
        );
        menuItems.add(
          MenuItemLabel(
            label: '★ ${recent.taskName}',
            enabled: !isRunning,
            onClicked: isRunning
                ? null
                : (_) => onStartTimer(recent.projectId, recent.taskId),
          ),
        );
      }
      menuItems.add(MenuSeparator());
    }

    // Start timer — project → task sub-menus
    if (projects.isNotEmpty && display.menuStartTimer) {
      menuItems.add(
        MenuItemLabel(label: '--- Start Timer ---', enabled: false),
      );
      for (final project in projects) {
        if (project.tasks.isEmpty) continue;
        final subMenu = SubMenu(label: project.name, children: []);
        for (final task in project.tasks) {
          subMenu.children.add(
            MenuItemLabel(
              label: task.name,
              onClicked: (_) => onStartTimer(project.id, task.id),
            ),
          );
        }
        menuItems.add(subMenu);
      }
      menuItems.add(MenuSeparator());
    }

    menuItems.add(MenuItemLabel(label: 'Quit', onClicked: (_) => _quitApp()));

    // The menu is refreshed every second; rebuilding the native menu only when
    // it changed keeps an open menu from flickering.
    final signature = _signature(menuItems);
    if (signature == _lastMenuSignature) return;
    _lastMenuSignature = signature;

    final menu = Menu();
    await menu.buildFrom(menuItems);
    await _systemTray.setContextMenu(menu);
  }

  static String _signature(List<MenuItemBase> items) {
    final buffer = StringBuffer();
    for (final item in items) {
      if (item is SubMenu) {
        buffer.write('[${item.label}:${_signature(item.children)}]');
      } else if (item is MenuItemLabel) {
        buffer.write('${item.label}|${item.enabled}|${item.onClicked != null};');
      } else {
        buffer.write('-;');
      }
    }
    return buffer.toString();
  }

  Future<void> destroy() async {
    if (!_isInitialized) return;
    await _systemTray.destroy();
    _isInitialized = false;
  }
}
