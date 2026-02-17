import 'package:hive_ce/hive.dart';

import '../../core/constants/app_constants.dart';
import '../models/category_model.dart';

class CategoryRepository {
  late Box<CategoryModel> _box;

  Future<void> init() async {
    _box = await Hive.openBox<CategoryModel>(AppConstants.categoriesBox);
  }

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
    await _box.delete(id);
  }

  Future<void> deleteAll() async {
    await _box.clear();
  }
}
