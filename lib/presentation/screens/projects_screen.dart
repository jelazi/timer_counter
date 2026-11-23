import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/pocketbase_sync_service.dart';
import '../../core/theme/desktop_theme.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/project_model.dart';
import '../../data/repositories/project_client_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../blocs/client/client_bloc.dart';
import '../blocs/client/client_state.dart';
import '../blocs/project/project_bloc.dart';
import '../blocs/project/project_event.dart';
import '../blocs/project/project_state.dart';
import '../widgets/desktop/pane_header.dart';
import '../widgets/project_form_dialog.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectBloc, ProjectState>(
      builder: (context, projectState) {
        return Builder(
          builder: (context) {
            final isMobile = MediaQuery.of(context).size.width < 600;
            if (!isMobile) {
              return Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surface,
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, projectState, pane: true),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [Expanded(child: _buildProjectsList(context, projectState))],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, projectState),
                    const SizedBox(height: 16),
                    Expanded(child: _buildProjectsList(context, projectState)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ProjectState projectState, {bool pane = false}) {
    bool showArchived = false;
    if (projectState is ProjectLoaded) {
      showArchived = projectState.showArchived;
    }

    final titleWidget = Text(tr('projects.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold));

    final searchField = TextField(
      decoration: InputDecoration(
        hintText: tr('common.search'),
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
      onChanged: (query) {
        context.read<ProjectBloc>().add(FilterProjects(searchQuery: query, showArchived: showArchived));
      },
    );

    final filterChip = FilterChip(
      label: Text(tr('projects.archived_projects')),
      selected: showArchived,
      onSelected: (selected) {
        context.read<ProjectBloc>().add(FilterProjects(showArchived: selected));
      },
    );

    final addProjectButton = FilledButton.icon(onPressed: () => _showAddProjectDialog(context), icon: const Icon(Icons.add), label: Text(tr('projects.add_project')));

    if (pane) {
      return PaneHeader(
        title: tr('projects.title'),
        actions: [
          SizedBox(width: 200, child: searchField),
          filterChip,
          addProjectButton,
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Narrow / mobile layout
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: titleWidget),
                  addProjectButton,
                ],
              ),
              const SizedBox(height: 12),
              searchField,
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [filterChip]),
            ],
          );
        }

        // Wide / desktop layout
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            titleWidget,
            Row(
              children: [
                SizedBox(width: 200, child: searchField),
                const SizedBox(width: 12),
                filterChip,
                const SizedBox(width: 12),
                const SizedBox(width: 8),
                addProjectButton,
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildProjectsList(BuildContext context, ProjectState projectState) {
    if (projectState is ProjectLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (projectState is ProjectLoaded) {
      if (projectState.filteredProjects.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_off_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(tr('projects.no_projects'), style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        );
      }

      final projects = projectState.filteredProjects;
      Widget card(ProjectModel project) => _ProjectCard(
        project: project,
        onTap: () => _openProjectDetail(context, project),
        onArchive: () => context.read<ProjectBloc>().add(project.isArchived ? UnarchiveProject(project.id) : ArchiveProject(project.id)),
        onDelete: () => _showDeleteProjectDialog(context, project),
        onEdit: () => _showEditProjectDialog(context, project),
      );

      // Cards in one row share the height of the tallest, so no card carries empty space.
      return LayoutBuilder(
        builder: (context, constraints) {
          const gap = 14.0;
          final columns = ((constraints.maxWidth + gap) / (440 + gap)).ceil().clamp(1, 6);
          return ListView(
            children: [
              for (var row = 0; row * columns < projects.length; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: gap),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var col = 0; col < columns; col++) ...[
                          if (col > 0) const SizedBox(width: gap),
                          Expanded(child: row * columns + col < projects.length ? card(projects[row * columns + col]) : const SizedBox()),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return const SizedBox();
  }

  void _showAddProjectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => ProjectFormDialog(
        onSave: (project) {
          context.read<ProjectBloc>().add(AddProject(project));
        },
      ),
    );
  }

  void _showEditProjectDialog(BuildContext context, ProjectModel project) {
    showDialog(
      context: context,
      builder: (_) => ProjectFormDialog(
        project: project,
        onSave: (updated) {
          context.read<ProjectBloc>().add(UpdateProject(updated));
        },
      ),
    );
  }

  void _showDeleteProjectDialog(BuildContext context, ProjectModel project) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('projects.delete_project')),
        content: Text(tr('projects.delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
          FilledButton(
            onPressed: () {
              // Collect data for undo before deleting
              final tasks = context.read<TaskRepository>().getByProject(project.id);
              final entries = context.read<TimeEntryRepository>().getByProject(project.id);

              context.read<ProjectBloc>().add(DeleteProject(project.id));
              Navigator.pop(context);

              // Show SnackBar with undo
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tr('projects.project_deleted')),
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: tr('common.undo'),
                    onPressed: () async {
                      if (!context.mounted) return;
                      final projectRepo = context.read<ProjectRepository>();
                      final syncService = context.read<PocketBaseSyncService?>();
                      final taskRepo = context.read<TaskRepository>();
                      final entryRepo = context.read<TimeEntryRepository>();
                      final projectBloc = context.read<ProjectBloc>();

                      // Restore project
                      await projectRepo.add(project);
                      syncService?.pushProject(project);
                      // Restore tasks
                      for (final task in tasks) {
                        await taskRepo.add(task);
                        syncService?.pushTask(task);
                      }
                      // Restore time entries
                      for (final entry in entries) {
                        await entryRepo.add(entry);
                        syncService?.pushTimeEntry(entry);
                      }
                      projectBloc.add(const LoadProjects());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('projects.project_restored')), backgroundColor: Colors.green));
                      }
                    },
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );
  }

  void _openProjectDetail(BuildContext context, ProjectModel project) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)));
  }
}

class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onTap;
  final VoidCallback onArchive;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ProjectCard({required this.project, required this.onTap, required this.onArchive, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientBloc, ClientState>(builder: (context, clientState) => _buildCard(context, clientState));
  }

  Widget _buildCard(BuildContext context, ClientState clientState) {
    final mac = MacColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = context.locale.toString();
    final currency = context.read<SettingsRepository>().getCurrency();
    final money = NumberFormat.decimalPattern(locale);
    final projectColor = Color(project.colorValue);

    final tasks = context.read<TaskRepository>().getByProject(project.id);
    final entries = context.read<TimeEntryRepository>().getByProject(project.id);
    final totalSeconds = entries.fold<int>(0, (sum, e) => sum + e.actualDurationSeconds);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final monthEntries = entries.where((e) => !e.startTime.isBefore(monthStart));
    final monthSeconds = monthEntries.fold<int>(0, (sum, e) => sum + e.actualDurationSeconds);
    final monthBillableSeconds = monthEntries.where((e) => e.isBillable).fold<int>(0, (sum, e) => sum + e.actualDurationSeconds);
    final billableTotal = entries.where((e) => e.isBillable).fold<int>(0, (sum, e) => sum + e.actualDurationSeconds) / 3600 * project.hourlyRate;
    final lastEntry = entries.isEmpty ? null : entries.map((e) => e.startTime).reduce((a, b) => a.isAfter(b) ? a : b);

    final links = context.read<ProjectClientRepository>().getByProject(project.id);
    final clientNames = clientState is ClientLoaded ? {for (final c in clientState.clients) c.id: c.name} : const <String, String>{};
    final clients = links.map((l) => clientNames[l.clientId]).whereType<String>().toList();
    final serviceDescription = links.isEmpty ? '' : links.first.serviceDescription;

    final overdue = project.dueDate != null && project.dueDate!.isBefore(DateTime(now.year, now.month, now.day)) && !project.isArchived;
    final dateFormat = DateFormat('d. M. yyyy', locale);

    Widget badge(String text, Color color) => Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: textTheme.labelSmall?.copyWith(color: color)),
    );

    Widget figure(String label, String value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelSmall, overflow: TextOverflow.ellipsis),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );

    Widget progress(String label, double done, double planned, String text) {
      final ratio = planned <= 0 ? 0.0 : done / planned;
      final over = ratio > 1;
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            SizedBox(width: 62, child: Text(label, style: textTheme.labelSmall)),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: mac.separator,
                  valueColor: AlwaysStoppedAnimation(over ? Theme.of(context).colorScheme.error : projectColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(text, style: textTheme.labelSmall?.copyWith(color: over ? Theme.of(context).colorScheme.error : null)),
          ],
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 3, color: projectColor),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!project.isBillable) badge(tr('projects.non_billable'), mac.secondaryLabel),
                        if (project.isArchived) badge(tr('projects.archived'), mac.secondaryLabel),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz, size: 18),
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                onEdit();
                              case 'archive':
                                onArchive();
                              case 'delete':
                                onDelete();
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(tr('common.edit'))),
                            PopupMenuItem(value: 'archive', child: Text(project.isArchived ? tr('projects.unarchive') : tr('projects.archive'))),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(tr('common.delete'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.business_outlined, size: 13, color: mac.secondaryLabel),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: clients.isEmpty
                                        ? [TextSpan(text: tr('projects.no_clients'))]
                                        : [
                                            TextSpan(
                                              text: clients.first,
                                              style: TextStyle(color: mac.label, fontWeight: FontWeight.w600),
                                            ),
                                            if (clients.length > 1) TextSpan(text: ' · ${clients.skip(1).join(', ')}'),
                                          ],
                                  ),
                                  style: textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (serviceDescription.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 18, top: 1),
                              child: Text(
                                serviceDescription,
                                style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              figure(tr('projects.this_month'), TimeFormatter.formatHumanReadable(monthSeconds)),
                              figure(tr('projects.total'), TimeFormatter.formatHumanReadable(totalSeconds)),
                              figure(tr('projects.rate'), project.hourlyRate > 0 ? '${money.format(project.hourlyRate)} $currency/h' : '—'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              figure(
                                tr('projects.month_amount'),
                                project.isBillable && project.hourlyRate > 0 ? '${money.format((monthBillableSeconds / 3600 * project.hourlyRate).round())} $currency' : '—',
                              ),
                              figure(tr('projects.tasks'), '${tasks.length}'),
                              figure(tr('projects.last_entry'), lastEntry == null ? tr('projects.no_entries') : dateFormat.format(lastEntry)),
                            ],
                          ),
                          if (project.plannedTimeHours > 0)
                            progress(
                              tr('projects.plan_time'),
                              totalSeconds / 3600,
                              project.plannedTimeHours,
                              '${(totalSeconds / 3600).round()} / ${project.plannedTimeHours.round()} h',
                            ),
                          if (project.plannedBudget > 0)
                            progress(
                              tr('projects.plan_budget'),
                              billableTotal,
                              project.plannedBudget,
                              '${money.format(billableTotal.round())} / ${money.format(project.plannedBudget.round())}',
                            ),
                          if (project.startDate != null || project.dueDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  Icon(Icons.event_outlined, size: 13, color: overdue ? Theme.of(context).colorScheme.error : mac.secondaryLabel),
                                  const SizedBox(width: 5),
                                  Text(
                                    [
                                          project.startDate == null ? '' : dateFormat.format(project.startDate!),
                                          project.dueDate == null ? '' : dateFormat.format(project.dueDate!),
                                        ].join(' – ') +
                                        (overdue ? ' · ${tr('projects.overdue')}' : ''),
                                    style: textTheme.bodySmall?.copyWith(color: overdue ? Theme.of(context).colorScheme.error : null),
                                  ),
                                ],
                              ),
                            ),
                          if (project.notes.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(project.notes.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
