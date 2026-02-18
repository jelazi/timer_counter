import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/project_model.dart';
import '../blocs/category/category_bloc.dart';
import '../blocs/category/category_state.dart';

class ProjectFormDialog extends StatefulWidget {
  final ProjectModel? project;
  final Function(ProjectModel project) onSave;

  const ProjectFormDialog({super.key, this.project, required this.onSave});

  @override
  State<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<ProjectFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _hourlyRateController;
  late TextEditingController _plannedTimeController;
  late TextEditingController _plannedBudgetController;
  late TextEditingController _monthlyRequiredHoursController;
  late TextEditingController _notesController;
  String? _selectedCategoryId;
  int _selectedColor = AppConstants.projectColors[0];
  bool _isBillable = true;
  DateTime? _startDate;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _hourlyRateController = TextEditingController(text: widget.project?.hourlyRate.toString() ?? '0');
    _plannedTimeController = TextEditingController(text: widget.project?.plannedTimeHours.toString() ?? '0');
    _plannedBudgetController = TextEditingController(text: widget.project?.plannedBudget.toString() ?? '0');
    _monthlyRequiredHoursController = TextEditingController(text: widget.project?.monthlyRequiredHours.toString() ?? '0');
    _notesController = TextEditingController(text: widget.project?.notes ?? '');

    if (widget.project != null) {
      _selectedCategoryId = widget.project!.categoryId;
      _selectedColor = widget.project!.colorValue;
      _isBillable = widget.project!.isBillable;
      _startDate = widget.project!.startDate;
      _dueDate = widget.project!.dueDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hourlyRateController.dispose();
    _plannedTimeController.dispose();
    _plannedBudgetController.dispose();
    _monthlyRequiredHoursController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.project != null;

    return AlertDialog(
      title: Text(isEditing ? tr('projects.edit_project') : tr('projects.add_project')),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: tr('projects.project_name')),
                autofocus: true,
              ),
              const SizedBox(height: 16),

              // Category
              BlocBuilder<CategoryBloc, CategoryState>(
                builder: (context, state) {
                  if (state is CategoryLoaded) {
                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: tr('projects.category')),
                      initialValue: _selectedCategoryId,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String>(value: null, child: Text(tr('categories.uncategorized'))),
                        ...state.categories.map((cat) {
                          return DropdownMenuItem(
                            value: cat.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(color: Color(cat.colorValue), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(cat.name),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedCategoryId = v);
                      },
                    );
                  }
                  return const SizedBox();
                },
              ),
              const SizedBox(height: 16),

              // Color picker
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
              const SizedBox(height: 16),

              // Hourly Rate & Budget
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hourlyRateController,
                      decoration: InputDecoration(labelText: tr('projects.hourly_rate'), suffixText: 'CZK/h'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _plannedBudgetController,
                      decoration: InputDecoration(labelText: tr('projects.planned_budget'), suffixText: 'CZK'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Planned Time
              TextField(
                controller: _plannedTimeController,
                decoration: InputDecoration(labelText: tr('projects.planned_time')),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Monthly Required Hours
              TextField(
                controller: _monthlyRequiredHoursController,
                decoration: InputDecoration(labelText: tr('projects.monthly_required_hours'), suffixText: 'h'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (date != null) {
                          setState(() => _startDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: tr('projects.start_date')),
                        child: Text(_startDate != null ? DateFormat('d.M.yyyy').format(_startDate!) : '-'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(context: context, initialDate: _dueDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (date != null) {
                          setState(() => _dueDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: tr('projects.due_date')),
                        child: Text(_dueDate != null ? DateFormat('d.M.yyyy').format(_dueDate!) : '-'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Billable
              SwitchListTile(title: Text(tr('projects.billable')), value: _isBillable, onChanged: (v) => setState(() => _isBillable = v), contentPadding: EdgeInsets.zero),

              // Notes
              TextField(
                controller: _notesController,
                decoration: InputDecoration(labelText: tr('projects.notes')),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
        FilledButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              final project = ProjectModel(
                id: widget.project?.id ?? const Uuid().v4(),
                name: _nameController.text,
                categoryId: _selectedCategoryId,
                colorValue: _selectedColor,
                hourlyRate: double.tryParse(_hourlyRateController.text) ?? 0,
                plannedTimeHours: double.tryParse(_plannedTimeController.text) ?? 0,
                plannedBudget: double.tryParse(_plannedBudgetController.text) ?? 0,
                monthlyRequiredHours: double.tryParse(_monthlyRequiredHoursController.text) ?? 0,
                startDate: _startDate,
                dueDate: _dueDate,
                notes: _notesController.text,
                isBillable: _isBillable,
                isArchived: widget.project?.isArchived ?? false,
                createdAt: widget.project?.createdAt ?? DateTime.now(),
              );
              widget.onSave(project);
              Navigator.pop(context);
            }
          },
          child: Text(tr('common.save')),
        ),
      ],
    );
  }
}
