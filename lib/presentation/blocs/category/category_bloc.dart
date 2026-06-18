import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/pocketbase_sync_service.dart';
import '../../../data/repositories/category_repository.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final CategoryRepository _categoryRepository;
  final PocketBaseSyncService? _syncService;
  StreamSubscription<SyncCollection>? _syncSubscription;

  CategoryBloc({required CategoryRepository categoryRepository, PocketBaseSyncService? syncService})
    : _categoryRepository = categoryRepository,
      _syncService = syncService,
      super(const CategoryInitial()) {
    on<LoadCategories>(_onLoadCategories);
    on<AddCategory>(_onAddCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<DeleteCategory>(_onDeleteCategory);
    on<CategoriesSyncedExternally>(_onCategoriesSyncedExternally);

    _startSyncListener();
  }

  /// Reload categories when a PocketBase subscription updates the local store.
  void _startSyncListener() {
    if (_syncService == null) return;
    _syncSubscription = _syncService.onCollectionChanged.listen((col) {
      if (col == SyncCollection.categories) {
        add(const CategoriesSyncedExternally());
      }
    });
  }

  void _onCategoriesSyncedExternally(CategoriesSyncedExternally event, Emitter<CategoryState> emit) {
    emit(CategoryLoaded(_categoryRepository.getAll()));
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

  @override
  Future<void> close() {
    _syncSubscription?.cancel();
    return super.close();
  }

  Future<void> _onAddCategory(AddCategory event, Emitter<CategoryState> emit) async {
    try {
      await _categoryRepository.add(event.category);
      _syncService?.pushCategory(event.category).catchError((e) => debugPrint('[CategoryBloc] sync push error: $e'));
      final categories = _categoryRepository.getAll();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onUpdateCategory(UpdateCategory event, Emitter<CategoryState> emit) async {
    try {
      await _categoryRepository.update(event.category);
      _syncService?.pushCategory(event.category).catchError((e) => debugPrint('[CategoryBloc] sync push error: $e'));
      final categories = _categoryRepository.getAll();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }

  Future<void> _onDeleteCategory(DeleteCategory event, Emitter<CategoryState> emit) async {
    try {
      await _categoryRepository.delete(event.categoryId);
      _syncService?.deleteCategory(event.categoryId).catchError((e) => debugPrint('[CategoryBloc] sync delete error: $e'));
      final categories = _categoryRepository.getAll();
      emit(CategoryLoaded(categories));
    } catch (e) {
      emit(CategoryError(e.toString()));
    }
  }
}
