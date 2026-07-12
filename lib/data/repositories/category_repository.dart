import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/deletion_journal_service.dart';
import '../models/category_model.dart';

class CategoryRepository {
  late Box<CategoryModel> _box;
  DeletionJournalService? _journal;

  Future<void> init() async {
    _box = await Hive.openBox<CategoryModel>(AppConstants.categoriesBox);
  }

  /// Record every deletion made through this repository into [journal].
  void attachJournal(DeletionJournalService journal) => _journal = journal;

  List<CategoryModel> getAll() {
    return _box.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  CategoryModel? getById(String id) {
    try {
      return _box.values.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> add(CategoryModel category) async {
    await _box.put(category.id, category);
  }

  Future<void> update(CategoryModel category) async {
    await _box.put(category.id, category);
  }

  Future<void> delete(String id) async {
    final category = _box.get(id);
    if (category != null) {
      _journal?.record(AppConstants.categoriesBox, id, category.toJson());
    }
    await _box.delete(id);
  }

  Future<void> deleteAll() async {
    for (final category in _box.values.toList()) {
      _journal?.record(AppConstants.categoriesBox, category.id, category.toJson(), source: DeleteSource.bulkClear);
    }
    await _box.clear();
  }
}
