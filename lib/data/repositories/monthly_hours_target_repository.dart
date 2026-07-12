import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/deletion_journal_service.dart';
import '../models/monthly_hours_target_model.dart';

class MonthlyHoursTargetRepository {
  late Box<MonthlyHoursTargetModel> _box;
  DeletionJournalService? _journal;

  Future<void> init() async {
    _box = await Hive.openBox<MonthlyHoursTargetModel>(AppConstants.monthlyHoursTargetsBox);
  }

  /// Record every deletion made through this repository into [journal].
  void attachJournal(DeletionJournalService journal) => _journal = journal;

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
    final target = _box.get(id);
    if (target != null) {
      _journal?.record(AppConstants.monthlyHoursTargetsBox, id, target.toJson());
    }
    await _box.delete(id);
  }

  Future<void> deleteAll() async {
    for (final target in _box.values.toList()) {
      _journal?.record(AppConstants.monthlyHoursTargetsBox, target.id, target.toJson(), source: DeleteSource.bulkClear);
    }
    await _box.clear();
  }
}
