import 'package:equatable/equatable.dart';

import '../../../data/models/category_model.dart';

abstract class CategoryEvent extends Equatable {
  const CategoryEvent();

  @override
  List<Object?> get props => [];
}

class LoadCategories extends CategoryEvent {
  const LoadCategories();
}

class AddCategory extends CategoryEvent {
  final CategoryModel category;
  const AddCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class UpdateCategory extends CategoryEvent {
  final CategoryModel category;
  const UpdateCategory(this.category);

  @override
  List<Object?> get props => [category];
}

class DeleteCategory extends CategoryEvent {
  final String categoryId;
  const DeleteCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

/// Emitted internally when a PocketBase subscription updates the local
/// categories collection, so the UI reloads with the remote changes.
class CategoriesSyncedExternally extends CategoryEvent {
  const CategoriesSyncedExternally();
}
