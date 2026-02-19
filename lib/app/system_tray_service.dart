import 'dart:io';

import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../core/services/dock_service.dart';

/// Callback signature for starting a timer from the tray menu.
typedef TrayStartTimerCallback = void Function(String projectId, String taskId);

/// Callback signature for stopping a timer from the tray menu.
typedef TrayStopTimerCallback = void Function(String timerId);

/// Info about a project+tasks for the tray menu.
class TrayProjectInfo {
  final String id;
  final String name;
  final List<TrayTaskInfo> tasks;

  const TrayProjectInfo({required this.id, required this.name, required this.tasks});
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

  const TrayRunningTimerInfo({required this.id, required this.projectId, required this.taskId, required this.projectName, required this.taskName, required this.elapsed});
}

/// Info about a recently used project+task for the tray menu.
class TrayRecentTaskInfo {
  final String projectId;
  final String taskId;
  final String projectName;
  final String taskName;
  final int projectColor;

  const TrayRecentTaskInfo({required this.projectId, required this.taskId, required this.projectName, required this.taskName, required this.projectColor});
}

class SystemTrayService {
  final SystemTray _systemTray = SystemTray();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _systemTray.initSystemTray(title: 'Timer Counter', iconPath: _getIconPath(), toolTip: 'Timer Counter - Time Tracking');

    final menu = Menu();
    await menu.buildFrom([MenuItemLabel(label: 'Show', onClicked: (_) => _showWindow()), MenuSeparator(), MenuItemLabel(label: 'Quit', onClicked: (_) => _quitApp())]);

    await _systemTray.setContextMenu(menu);

    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        _systemTray.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });

    _isInitialized = true;
  }

  String _getIconPath() {
    if (Platform.isMacOS) {
      return 'assets/icons/app_icon.png';
    } else if (Platform.isWindows) {
      return 'assets/icons/app_icon.ico';
    }
    return 'assets/icons/app_icon.png';
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
    if (!_isInitialized) return;
    await _systemTray.setToolTip(tooltip);
  }

  Future<void> updateTitle(String title) async {
    if (!_isInitialized) return;
    await _systemTray.setTitle(title);
  }

  /// Build a rich tray menu with running timers, recent tasks, and project/task quick-start.
  Future<void> updateMenu({
    required List<TrayRunningTimerInfo> runningTimers,
    required List<TrayRecentTaskInfo> recentTasks,
    required List<TrayProjectInfo> projects,
    required VoidCallback onStopAll,
    required TrayStopTimerCallback onStopTimer,
    required TrayStartTimerCallback onStartTimer,
  }) async {
    if (!_isInitialized) return;

    final menuItems = <MenuItemBase>[MenuItemLabel(label: 'Show Timer Counter', onClicked: (_) => _showWindow()), MenuSeparator()];

    // Running timers section
    if (runningTimers.isNotEmpty) {
      for (final timer in runningTimers) {
        menuItems.add(MenuItemLabel(label: '▶ ${timer.projectName} / ${timer.taskName}  (${timer.elapsed})', onClicked: (_) => onStopTimer(timer.id)));
      }
      menuItems.add(MenuItemLabel(label: 'Stop All Timers', onClicked: (_) => onStopAll()));
      menuItems.add(MenuSeparator());
    }

    // Recent tasks — shown at root level for quick access
    if (recentTasks.isNotEmpty) {
      // Collect running project+task pairs to disable them
      final runningPairs = runningTimers.map((t) => '${t.projectId}:${t.taskId}').toSet();
      for (final recent in recentTasks) {
        final isRunning = runningPairs.contains('${recent.projectId}:${recent.taskId}');
        menuItems.add(MenuItemLabel(label: '★ ${recent.taskName}', enabled: !isRunning, onClicked: isRunning ? null : (_) => onStartTimer(recent.projectId, recent.taskId)));
      }
      menuItems.add(MenuSeparator());
    }

    // Start timer — project → task sub-menus
    if (projects.isNotEmpty) {
      menuItems.add(MenuItemLabel(label: '--- Start Timer ---', enabled: false));
      for (final project in projects) {
        if (project.tasks.isEmpty) continue;
        final subMenu = SubMenu(label: project.name, children: []);
        for (final task in project.tasks) {
          subMenu.children.add(MenuItemLabel(label: task.name, onClicked: (_) => onStartTimer(project.id, task.id)));
        }
        menuItems.add(subMenu);
      }
      menuItems.add(MenuSeparator());
    }

    menuItems.add(MenuItemLabel(label: 'Quit', onClicked: (_) => _quitApp()));

    final menu = Menu();
    await menu.buildFrom(menuItems);
    await _systemTray.setContextMenu(menu);
  }

  Future<void> destroy() async {
    if (!_isInitialized) return;
    await _systemTray.destroy();
    _isInitialized = false;
  }
}
