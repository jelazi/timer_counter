import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/monthly_hours_target_model.dart';

class MonthlyHoursTargetRepository {
  late Box<MonthlyHoursTargetModel> _box;

  Future<void> init() async {
    _box = await Hive.openBox<MonthlyHoursTargetModel>(AppConstants.monthlyHoursTargetsBox);
  }

  List<MonthlyHoursTargetModel> getAll() {
    return _box.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  MonthlyHoursTargetModel? getById(String id) {
    try {
      return _box.values.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(MonthlyHoursTargetModel target) async {
    await _box.put(target.id, target);
  }

  Future<void> update(MonthlyHoursTargetModel target) async {
    await _box.put(target.id, target);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> deleteAll() async {
    await _box.clear();
  }
}
