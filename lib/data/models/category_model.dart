import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

import '../../core/utils/json_utils.dart';

part 'category_model.g.dart';

@HiveType(typeId: 0)
class CategoryModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int colorValue;

  @HiveField(3)
  final DateTime createdAt;

  const CategoryModel({required this.id, required this.name, required this.colorValue, required this.createdAt});

  CategoryModel copyWith({String? id, String? name, int? colorValue, DateTime? createdAt}) {
    return CategoryModel(id: id ?? this.id, name: name ?? this.name, colorValue: colorValue ?? this.colorValue, createdAt: createdAt ?? this.createdAt);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'colorValue': colorValue, 'createdAt': createdAt.toIso8601String()};

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
    id: parseString(json['id']),
    name: parseString(json['name']),
    colorValue: parseInt(json['colorValue']),
    createdAt: parseDate(json['createdAt']),
  );

  @override
  List<Object?> get props => [id, name, colorValue, createdAt];
}
