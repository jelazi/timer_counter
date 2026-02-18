import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/utils/time_formatter.dart';
import '../../data/models/category_model.dart';
import '../../data/models/project_model.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../blocs/category/category_bloc.dart';
import '../blocs/category/category_event.dart';
import '../blocs/category/category_state.dart';
import '../blocs/project/project_bloc.dart';
import '../blocs/project/project_event.dart';
import '../blocs/project/project_state.dart';
import '../widgets/category_form_dialog.dart';
import '../widgets/project_form_dialog.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProjectBloc, ProjectState>(
      builder: (context, projectState) {
        return BlocBuilder<CategoryBloc, CategoryState>(
          builder: (context, categoryState) {
            return Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, projectState),
                    const SizedBox(height: 16),
                    if (categoryState is CategoryLoaded) _buildCategoryFilter(context, categoryState, projectState),
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

  Widget _buildHeader(BuildContext context, ProjectState projectState) {
    bool showArchived = false;
    if (projectState is ProjectLoaded) {
      showArchived = projectState.showArchived;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(tr('projects.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        Row(
          children: [
            // Search
            SizedBox(
              width: 200,
              child: TextField(
                decoration: InputDecoration(
                  hintText: tr('common.search'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                onChanged: (query) {
                  context.read<ProjectBloc>().add(FilterProjects(searchQuery: query, showArchived: showArchived));
                },
              ),
            ),
            const SizedBox(width: 12),
            // Toggle archived
            FilterChip(
              label: Text(tr('projects.archived_projects')),
              selected: showArchived,
              onSelected: (selected) {
                context.read<ProjectBloc>().add(FilterProjects(showArchived: selected));
              },
            ),
            const SizedBox(width: 12),
            // Add Category
            OutlinedButton.icon(onPressed: () => _showAddCategoryDialog(context), icon: const Icon(Icons.category, size: 18), label: Text(tr('categories.add_category'))),
            const SizedBox(width: 8),
            // Add Project
            FilledButton.icon(onPressed: () => _showAddProjectDialog(context), icon: const Icon(Icons.add), label: Text(tr('projects.add_project'))),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryFilter(BuildContext context, CategoryLoaded categoryState, ProjectState projectState) {
    String? selectedCategoryId;
    bool showArchived = false;
    String searchQuery = '';
    if (projectState is ProjectLoaded) {
      selectedCategoryId = projectState.selectedCategoryId;
      showArchived = projectState.showArchived;
      searchQuery = projectState.searchQuery;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text(tr('projects.active_projects')),
            selected: selectedCategoryId == null,
            onSelected: (_) {
              context.read<ProjectBloc>().add(FilterProjects(showArchived: showArchived, searchQuery: searchQuery));
            },
          ),
          const SizedBox(width: 8),
          ...categoryState.categories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                avatar: CircleAvatar(backgroundColor: Color(category.colorValue), radius: 8),
                label: Text(category.name),
                selected: selectedCategoryId == category.id,
                onSelected: (_) {
                  context.read<ProjectBloc>().add(
                    FilterProjects(categoryId: selectedCategoryId == category.id ? null : category.id, showArchived: showArchived, searchQuery: searchQuery),
                  );
                },
                onDeleted: () => _showDeleteCategoryDialog(context, category),
                deleteIcon: const Icon(Icons.close, size: 14),
              ),
            );
          }),
        ],
      ),
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

      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 400, childAspectRatio: 1.4, crossAxisSpacing: 16, mainAxisSpacing: 16),
        itemCount: projectState.filteredProjects.length,
        itemBuilder: (context, index) {
          final project = projectState.filteredProjects[index];
          return _ProjectCard(
            project: project,
            onTap: () => _openProjectDetail(context, project),
            onArchive: () {
              if (project.isArchived) {
                context.read<ProjectBloc>().add(UnarchiveProject(project.id));
              } else {
                context.read<ProjectBloc>().add(ArchiveProject(project.id));
              }
            },
            onDelete: () => _showDeleteProjectDialog(context, project),
            onEdit: () => _showEditProjectDialog(context, project),
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
              context.read<ProjectBloc>().add(DeleteProject(project.id));
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CategoryFormDialog(
        onSave: (category) {
          context.read<CategoryBloc>().add(AddCategory(category));
        },
      ),
    );
  }

  void _showDeleteCategoryDialog(BuildContext context, CategoryModel category) {
    // Check if category has projects
    final projectRepo = context.read<ProjectRepository>();
    final categoryProjects = projectRepo.getByCategory(category.id);
    if (categoryProjects.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(tr('categories.delete_category')),
          content: Text(tr('categories.cannot_delete_has_projects')),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.ok')))],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('categories.delete_category')),
        content: Text(tr('categories.delete_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('common.cancel'))),
          FilledButton(
            onPressed: () {
              context.read<CategoryBloc>().add(DeleteCategory(category.id));
              Navigator.pop(context);
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
    final taskRepo = context.read<TaskRepository>();
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final tasks = taskRepo.getByProject(project.id);
    final totalSeconds = timeEntryRepo.getTotalDurationForProject(project.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color bar
            Container(height: 4, color: Color(project.colorValue)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            project.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                onEdit();
                                break;
                              case 'archive':
                                onArchive();
                                break;
                              case 'delete':
                                onDelete();
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(tr('common.edit'))),
                            PopupMenuItem(value: 'archive', child: Text(project.isArchived ? tr('projects.unarchive') : tr('projects.archive'))),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(tr('common.delete'), style: const TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Stats
                    Row(
                      children: [
                        _StatChip(icon: Icons.access_time, label: TimeFormatter.formatHumanReadable(totalSeconds)),
                        const SizedBox(width: 12),
                        _StatChip(icon: Icons.list, label: '${tasks.length} ${tr('projects.tasks').toLowerCase()}'),
                      ],
                    ),
                    if (project.plannedTimeHours > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (totalSeconds / 3600) / project.plannedTimeHours,
                        backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(Color(project.colorValue)),
                      ),
                      const SizedBox(height: 4),
                      Text('${TimeFormatter.formatDecimalHours(totalSeconds)} / ${project.plannedTimeHours}h', style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (project.isBillable && project.hourlyRate > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${tr('projects.hourly_rate')}: ${project.hourlyRate.toStringAsFixed(0)} CZK',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                    if (project.monthlyRequiredHours > 0) ...[
                      const SizedBox(height: 4),
                      () {
                        final now = DateTime.now();
                        final monthStart = DateTime(now.year, now.month, 1);
                        final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
                        final monthEntries = timeEntryRepo.getByDateRange(monthStart, monthEnd);
                        final monthSeconds = monthEntries.where((e) => e.projectId == project.id).fold<int>(0, (sum, e) => sum + e.actualDurationSeconds);
                        final monthHours = monthSeconds / 3600;
                        final progress = monthHours / project.monthlyRequiredHours;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? Colors.green : Colors.orange),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${monthHours.toStringAsFixed(1)} / ${project.monthlyRequiredHours.toStringAsFixed(0)}h ${tr('projects.monthly_short')}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: progress >= 1.0 ? Colors.green : Colors.orange, fontWeight: FontWeight.w500),
                            ),
                          ],
                        );
                      }(),
                    ],
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

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
      ],
    );
  }
}
