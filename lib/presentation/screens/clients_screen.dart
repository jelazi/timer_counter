import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/desktop_theme.dart';
import '../../data/models/client_model.dart';
import '../../data/repositories/project_repository.dart';
import '../blocs/client/client_bloc.dart';
import '../blocs/client/client_event.dart';
import '../blocs/client/client_state.dart';
import '../widgets/client_form_dialog.dart';
import '../widgets/desktop/pane_header.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _query = '';
  bool _showArchived = false;

  Future<void> _add() async {
    final client = await ClientFormDialog.show(context);
    if (client != null && mounted) context.read<ClientBloc>().add(AddClient(client));
  }

  Future<void> _edit(ClientModel client) async {
    final updated = await ClientFormDialog.show(context, client: client);
    if (updated != null && mounted) context.read<ClientBloc>().add(UpdateClient(updated));
  }

  Future<void> _delete(ClientModel client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('clients.delete')),
        content: Text(tr('clients.delete_confirm', namedArgs: {'name': client.name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) context.read<ClientBloc>().add(DeleteClient(client.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ClientBloc, ClientState>(
      listenWhen: (_, state) => state is ClientLoaded && state.message != null,
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr((state as ClientLoaded).message!)))),
      builder: (context, state) {
        final clients = state is ClientLoaded ? state.clients : const <ClientModel>[];
        final query = _query.toLowerCase();
        final visible = clients.where((c) => _showArchived || !c.isArchived).where((c) => query.isEmpty || c.name.toLowerCase().contains(query) || c.ico.contains(query)).toList();

        final isMobile = MediaQuery.of(context).size.width < 600;
        final searchField = TextField(
          decoration: InputDecoration(hintText: tr('clients.search'), prefixIcon: const Icon(Icons.search, size: 16)),
          onChanged: (v) => setState(() => _query = v),
        );
        final archivedChip = FilterChip(label: Text(tr('clients.show_archived')), selected: _showArchived, onSelected: (v) => setState(() => _showArchived = v));

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(tr('clients.title'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                          IconButton.filled(onPressed: _add, icon: const Icon(Icons.add), tooltip: tr('clients.add')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      searchField,
                      const SizedBox(height: 8),
                      archivedChip,
                    ],
                  ),
                )
              else
                PaneHeader(
                  title: tr('clients.title'),
                  subtitle: tr('clients.subtitle'),
                  actions: [
                    SizedBox(width: 200, child: searchField),
                    archivedChip,
                    FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: Text(tr('clients.add'))),
                  ],
                ),
              Expanded(
                child: visible.isEmpty
                    ? _EmptyState(onAdd: _add)
                    : ListView(
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        children: [
                          _ClientGroup(
                            clients: visible,
                            state: state is ClientLoaded ? state : null,
                            onEdit: _edit,
                            onDelete: _delete,
                            onToggleArchive: (c) => context.read<ClientBloc>().add(UpdateClient(c.copyWith(isArchived: !c.isArchived))),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final mac = MacColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.business_outlined, size: 40, color: mac.tertiaryLabel),
          const SizedBox(height: 10),
          Text(tr('clients.no_clients'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(tr('clients.no_clients_hint'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(tr('clients.add'))),
        ],
      ),
    );
  }
}

class _ClientGroup extends StatelessWidget {
  final List<ClientModel> clients;
  final ClientLoaded? state;
  final ValueChanged<ClientModel> onEdit;
  final ValueChanged<ClientModel> onDelete;
  final ValueChanged<ClientModel> onToggleArchive;

  const _ClientGroup({required this.clients, required this.state, required this.onEdit, required this.onDelete, required this.onToggleArchive});

  @override
  Widget build(BuildContext context) {
    final mac = MacColors.of(context);
    final projectRepo = context.read<ProjectRepository>();
    final textTheme = Theme.of(context).textTheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: mac.groupFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mac.groupBorder),
      ),
      child: Column(
        children: [
          for (var i = 0; i < clients.length; i++)
            Builder(
              builder: (context) {
                final client = clients[i];
                final projects = (state?.linksOfClient(client.id) ?? const []).map((l) => projectRepo.getById(l.projectId)?.name).whereType<String>().toList();
                final details = [
                  client.ico.isNotEmpty ? '${tr('clients.ico')}: ${client.ico}' : null,
                  client.addressLine2.isNotEmpty ? client.addressLine2 : null,
                ].whereType<String>();

                return InkWell(
                  onTap: () => onEdit(client),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: i == clients.length - 1 ? null : Border(bottom: BorderSide(color: mac.separator)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      client.name,
                                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (client.isArchived) ...[const SizedBox(width: 8), Text(tr('clients.archived'), style: textTheme.labelSmall)],
                                ],
                              ),
                              if (details.isNotEmpty) Text(details.join(' · '), style: textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            projects.isEmpty ? tr('clients.no_projects') : projects.join(', '),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz, size: 18),
                          onSelected: (action) {
                            switch (action) {
                              case 'edit':
                                onEdit(client);
                              case 'archive':
                                onToggleArchive(client);
                              case 'delete':
                                onDelete(client);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(tr('clients.edit'))),
                            PopupMenuItem(value: 'archive', child: Text(tr(client.isArchived ? 'clients.unarchive' : 'clients.archive'))),
                            PopupMenuItem(value: 'delete', child: Text(tr('clients.delete'))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
