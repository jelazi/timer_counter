import 'package:window_manager/window_manager.dart';

import '../core/services/dock_service.dart';
import '../data/repositories/settings_repository.dart';

/// Handles desktop-specific window events (close-to-tray, minimize-to-tray).
/// Created only on desktop platforms.
class DesktopWindowHandler with WindowListener {
  final SettingsRepository _settingsRepo;

  DesktopWindowHandler({required SettingsRepository settingsRepo}) : _settingsRepo = settingsRepo {
    windowManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
      await DockService.hideFromDock();
    }
  }

  @override
  void onWindowMinimize() async {
    final minimizeToTray = _settingsRepo.getMinimizeToTray();
    if (minimizeToTray) {
      await windowManager.hide();
      await DockService.hideFromDock();
    }
  }

  void dispose() {
    windowManager.removeListener(this);
  }
}
