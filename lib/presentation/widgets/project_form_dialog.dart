import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/desktop_theme.dart';
import '../../data/models/client_model.dart';
import '../../data/models/project_model.dart';
import '../../data/repositories/project_client_repository.dart';
import '../blocs/client/client_bloc.dart';
import '../blocs/client/client_event.dart';
import '../blocs/client/client_state.dart';
import 'app_switch_tile.dart';
import 'client_form_dialog.dart';

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
  late TextEditingController _notesController;
  String? _selectedCategoryId;
  int _selectedColor = AppConstants.projectColors[0];
  bool _isBillable = true;
  DateTime? _startDate;
  DateTime? _dueDate;
  late final String _projectId;

  /// Linked clients in the user's order; the first one is offered on invoices.
  final List<String> _clientIds = [];
  final Map<String, TextEditingController> _descriptions = {};

  @override
  void initState() {
    super.initState();
    _projectId = widget.project?.id ?? const Uuid().v4();
    for (final link in context.read<ProjectClientRepository>().getByProject(_projectId)) {
      _clientIds.add(link.clientId);
      _descriptions[link.clientId] = TextEditingController(text: link.serviceDescription);
    }
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _hourlyRateController = TextEditingController(text: widget.project?.hourlyRate.toString() ?? '0');
    _plannedTimeController = TextEditingController(text: widget.project?.plannedTimeHours.toString() ?? '0');
    _plannedBudgetController = TextEditingController(text: widget.project?.plannedBudget.toString() ?? '0');
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
    _notesController.dispose();
    for (final c in _descriptions.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _linkClient(String clientId) {
    if (_clientIds.contains(clientId)) return;
    setState(() {
      _clientIds.add(clientId);
      _descriptions[clientId] = TextEditingController();
    });
  }

  void _unlinkClient(String clientId) {
    setState(() {
      _clientIds.remove(clientId);
      _descriptions.remove(clientId)?.dispose();
    });
  }

  Future<void> _createAndLinkClient() async {
    final client = await ClientFormDialog.show(context);
    if (client == null || !mounted) return;
    context.read<ClientBloc>().add(AddClient(client));
    _linkClient(client.id);
  }

  Widget _buildClientsSection(BuildContext context) {
    final mac = MacColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<ClientBloc, ClientState>(
      builder: (context, state) {
        final all = state is ClientLoaded ? state.clients : const <ClientModel>[];
        final byId = {for (final c in all) c.id: c};
        final available = all.where((c) => !c.isArchived && !_clientIds.contains(c.id)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(tr('projects.clients'), style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                PopupMenuButton<String>(
                  tooltip: tr('projects.add_client'),
                  onSelected: (value) => value == '__new__' ? _createAndLinkClient() : _linkClient(value),
                  itemBuilder: (_) => [
                    for (final c in available) PopupMenuItem(value: c.id, child: Text(c.name)),
                    if (available.isNotEmpty) const PopupMenuDivider(),
                    PopupMenuItem(value: '__new__', child: Text(tr('projects.new_client'))),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 15, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(tr('projects.add_client'), style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_clientIds.isEmpty)
              Text(tr('projects.no_clients'), style: textTheme.bodySmall)
            else ...[
              ReorderableListView(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                physics: const NeverScrollableScrollPhysics(),
                onReorderItem: (from, to) => setState(() => _clientIds.insert(to, _clientIds.removeAt(from))),
                children: [
                  for (var i = 0; i < _clientIds.length; i++)
                    Padding(
                      key: ValueKey(_clientIds[i]),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(Icons.drag_indicator, size: 18, color: mac.tertiaryLabel),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 150,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  byId[_clientIds[i]]?.name ?? '—',
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                ),
                                if (i == 0) Text(tr('projects.invoice_default'), style: textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _descriptions[_clientIds[i]],
                              decoration: InputDecoration(hintText: tr('projects.service_description')),
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.remove_circle_outline), tooltip: tr('common.delete'), onPressed: () => _unlinkClient(_clientIds[i])),
                        ],
                      ),
                    ),
                ],
              ),
              Text(tr('projects.default_client_hint'), style: textTheme.bodySmall?.copyWith(color: mac.tertiaryLabel)),
            ],
          ],
        );
      },
    );
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

              _buildClientsSection(context),
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
              AppSwitchTile(title: Text(tr('projects.billable')), value: _isBillable, onChanged: (v) => setState(() => _isBillable = v), contentPadding: EdgeInsets.zero),

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
                id: _projectId,
                name: _nameController.text,
                categoryId: _selectedCategoryId,
                colorValue: _selectedColor,
                hourlyRate: double.tryParse(_hourlyRateController.text) ?? 0,
                plannedTimeHours: double.tryParse(_plannedTimeController.text) ?? 0,
                plannedBudget: double.tryParse(_plannedBudgetController.text) ?? 0,
                startDate: _startDate,
                dueDate: _dueDate,
                notes: _notesController.text,
                isBillable: _isBillable,
                isArchived: widget.project?.isArchived ?? false,
                createdAt: widget.project?.createdAt ?? DateTime.now(),
              );
              widget.onSave(project);
              context.read<ClientBloc>().add(SetProjectClients(projectId: _projectId, clients: {for (final id in _clientIds) id: _descriptions[id]!.text.trim()}));
              Navigator.pop(context);
            }
          },
          child: Text(tr('common.save')),
        ),
      ],
    );
  }
}
