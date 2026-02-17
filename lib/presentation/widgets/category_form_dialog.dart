import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/category_model.dart';

class CategoryFormDialog extends StatefulWidget {
  final CategoryModel? category;
  final Function(CategoryModel category) onSave;

  const CategoryFormDialog({super.key, this.category, required this.onSave});

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  late TextEditingController _nameController;
  int _selectedColor = AppConstants.projectColors[0];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    if (widget.category != null) {
      _selectedColor = widget.category!.colorValue;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return AlertDialog(
      title: Text(isEditing ? tr('categories.edit_category') : tr('categories.add_category')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: tr('categories.category_name')),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(tr('projects.color'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AppConstants.projectColors.map((colorValue) {
                final isSelected = _selectedColor == colorValue;
                return InkWell(
                  onTap: () {
                    setState(() => _selectedColor = colorValue);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(colorValue),
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2) : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              final category = CategoryModel(
                id: widget.category?.id ?? const Uuid().v4(),
                name: _nameController.text,
                colorValue: _selectedColor,
                createdAt: widget.category?.createdAt ?? DateTime.now(),
              );
              widget.onSave(category);
              Navigator.pop(context);
            }
          },
          child: Text(tr('common.save')),
        ),
      ],
    );
  }
}
