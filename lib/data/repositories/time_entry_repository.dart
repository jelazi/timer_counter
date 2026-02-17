import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/time_entry_model.dart';

class TimeEntryRepository {
  late Box<TimeEntryModel> _box;

  Future<void> init() async {
    _box = await Hive.openBox<TimeEntryModel>(AppConstants.timeEntriesBox);
  }

  List<TimeEntryModel> getAll() {
    return _box.values.toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  List<TimeEntryModel> getByDateRange(DateTime start, DateTime end) {
    return _box.values.where((e) => e.startTime.isAfter(start.subtract(const Duration(seconds: 1))) && e.startTime.isBefore(end.add(const Duration(seconds: 1)))).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  List<TimeEntryModel> getToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return getByDateRange(startOfDay, endOfDay);
  }

  List<TimeEntryModel> getThisWeek() {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return getByDateRange(startOfWeek, endOfWeek);
  }

  List<TimeEntryModel> getThisMonth() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return getByDateRange(startOfMonth, endOfMonth);
  }

  List<TimeEntryModel> getByProject(String projectId) {
    return _box.values.where((e) => e.projectId == projectId).toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  List<TimeEntryModel> getByTask(String taskId) {
    return _box.values.where((e) => e.taskId == taskId).toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  TimeEntryModel? getById(String id) {
    try {
      return _box.values.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(TimeEntryModel entry) async {
    await _box.put(entry.id, entry);
  }

  Future<void> update(TimeEntryModel entry) async {
    await _box.put(entry.id, entry);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> deleteByProject(String projectId) async {
    final entries = getByProject(projectId);
    for (final entry in entries) {
      await _box.delete(entry.id);
    }
  }

  Future<void> deleteByTask(String taskId) async {
    final entries = getByTask(taskId);
    for (final entry in entries) {
      await _box.delete(entry.id);
    }
  }

  /// Get total duration in seconds for a given date range
  int getTotalDurationForRange(DateTime start, DateTime end) {
    final entries = getByDateRange(start, end);
    return entries.fold(0, (sum, e) => sum + e.actualDurationSeconds);
  }

  /// Get total duration in seconds for a specific project
  int getTotalDurationForProject(String projectId) {
    final entries = getByProject(projectId);
    return entries.fold(0, (sum, e) => sum + e.actualDurationSeconds);
  }

  /// Get total duration in seconds for a specific task
  int getTotalDurationForTask(String taskId) {
    final entries = getByTask(taskId);
    return entries.fold(0, (sum, e) => sum + e.actualDurationSeconds);
  }
}
