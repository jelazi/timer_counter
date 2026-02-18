import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/firebase_sync_service_v2.dart';
import '../../../data/repositories/category_repository.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository _categoryRepository;
  final FirebaseSyncService? _firebaseSyncService;

  CategoryBloc({required CategoryRepository categoryRepository, FirebaseSyncService? firebaseSyncService})
    : _categoryRepository = categoryRepository,
      _firebaseSyncService = firebaseSyncService,
      super(const CategoryInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<AddCategory>(_onAddCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);
  }

  void _onLoadCategories(LoadCategories event, Emitter<CategoryState> emit) {
    try {
      emit(const CategoryLoading());
      final categories = _categoryRepository.getAll();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onAddCategory(AddCategory event, Emitter<CategoryState> emit) async {
    try {
      await _categoryRepository.add(event.category);
      _firebaseSyncService?.pushCategory(event.category).catchError((e) => debugPrint('[CategoryBloc] sync push error: $e'));
      final categories = _categoryRepository.getAll();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onUpdateCategory(UpdateCategory event, Emitter<CategoryState> emit) async {
    try {
      await _categoryRepository.update(event.category);
      _firebaseSyncService?.pushCategory(event.category).catchError((e) => debugPrint('[CategoryBloc] sync push error: $e'));
      final categories = _categoryRepository.getAll();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onDeleteCategory(DeleteCategory event, Emitter<CategoryState> emit) async {
    try {
      await _categoryRepository.delete(event.categoryId);
      _firebaseSyncService?.deleteCategory(event.categoryId).catchError((e) => debugPrint('[CategoryBloc] sync delete error: $e'));
      final categories = _categoryRepository.getAll();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }
}
