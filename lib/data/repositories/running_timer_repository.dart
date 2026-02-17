import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/running_timer_model.dart';

class RunningTimerRepository {
  late Box<RunningTimerModel> _box;

  Future<void> init() async {
    _box = await Hive.openBox<RunningTimerModel>(AppConstants.runningTimersBox);
  }

  List<RunningTimerModel> getAll() {
    return _box.values.toList();
  }

  RunningTimerModel? getById(String id) {
    try {
      return _box.values.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  RunningTimerModel? getByTaskId(String taskId) {
    try {
      return _box.values.firstWhere((t) => t.taskId == taskId);
    } catch (_) {
      return null;
    }
  }

  bool isRunning(String taskId) {
    return _box.values.any((t) => t.taskId == taskId);
  }

  bool get hasRunningTimers => _box.values.isNotEmpty;

  Future<void> start(RunningTimerModel timer) async {
    await _box.put(timer.id, timer);
  }

  Future<void> stop(String id) async {
    await _box.delete(id);
  }

  Future<void> stopAll() async {
    await _box.clear();
  }

  Future<void> updateNotes(String id, String notes) async {
    final timer = getById(id);
    if (timer != null) {
      await _box.put(id, timer.copyWith(notes: notes));
    }
  }
}
