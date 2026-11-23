import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/services/client_migration_service.dart';
import '../../core/services/pocketbase_sync_service.dart';
import '../../core/theme/desktop_theme.dart';
import '../../data/repositories/client_repository.dart';
import '../../data/repositories/project_client_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/standalone_invoice_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../blocs/client/client_bloc.dart';
import '../blocs/client/client_event.dart';
import '../blocs/standalone_invoice/standalone_invoice_bloc.dart';
import '../blocs/standalone_invoice/standalone_invoice_event.dart';

/// Shows what [ClientMigrationService] would create from the existing invoices and applies it on confirmation.
class ClientMigrationDialog extends StatefulWidget {
  final ClientMigrationService service;
  final ClientMigrationPlan plan;

  const ClientMigrationDialog({super.key, required this.service, required this.plan});

  static ClientMigrationService serviceOf(BuildContext context) => ClientMigrationService(
    invoiceRepository: context.read<StandaloneInvoiceRepository>(),
    clientRepository: context.read<ClientRepository>(),
    projectClientRepository: context.read<ProjectClientRepository>(),
    projectRepository: context.read<ProjectRepository>(),
    timeEntryRepository: context.read<TimeEntryRepository>(),
    settingsRepository: context.read<SettingsRepository>(),
  );

  /// Opens the preview; with [onlyIfNeeded] nothing is shown when there is nothing to do.
  static Future<void> show(BuildContext context, {bool onlyIfNeeded = false}) async {
    final service = serviceOf(context);
    final plan = service.buildPlan();
    if (plan.isEmpty) {
      if (!onlyIfNeeded) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('client_migration.nothing'))));
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClientMigrationDialog(service: service, plan: plan),
    );
  }

  @override
  State<ClientMigrationDialog> createState() => _ClientMigrationDialogState();
}

class _ClientMigrationDialogState extends State<ClientMigrationDialog> {
  bool _running = false;

  Future<void> _apply() async {
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<SettingsRepository>();
    final clientBloc = context.read<ClientBloc>();
    final invoiceBloc = context.read<StandaloneInvoiceBloc>();
    await widget.service.apply(widget.plan, syncService: context.read<PocketBaseSyncService?>());
    await settings.setClientMigrationOffered(true);
    clientBloc.add(const LoadClients());
    invoiceBloc.add(const LoadStandaloneInvoices());
    if (mounted) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(tr('client_migration.done'))));
  }

  Future<void> _later() async {
    await context.read<SettingsRepository>().setClientMigrationOffered(true);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final textTheme = Theme.of(context).textTheme;
    final mac = MacColors.of(context);
    final projectRepo = context.read<ProjectRepository>();
    final clientRepo = context.read<ClientRepository>();

    String clientName(String id) => plan.newClients.where((c) => c.id == id).map((c) => c.name).firstOrNull ?? clientRepo.getById(id)?.name ?? '—';

    final linksByClient = <String, List<String>>{};
    for (final link in plan.newLinks) {
      linksByClient.putIfAbsent(link.clientId, () => []).add(projectRepo.getById(link.projectId)?.name ?? link.projectId);
    }
    final invoicesByClient = <String, int>{};
    for (final invoice in plan.updatedInvoices) {
      invoicesByClient.update(invoice.clientId!, (n) => n + 1, ifAbsent: () => 1);
    }
    final clientIds = {...plan.newClients.map((c) => c.id), ...linksByClient.keys, ...invoicesByClient.keys};

    return AlertDialog(
      title: Text(tr('client_migration.title')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('client_migration.intro'), style: textTheme.bodyMedium),
              const SizedBox(height: 14),
              for (final id in clientIds)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: mac.groupFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: mac.groupBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.business_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(clientName(id), style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          if (plan.newClients.any((c) => c.id == id)) Text(tr('client_migration.new'), style: textTheme.labelSmall),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tr('client_migration.projects')}: ${(linksByClient[id] ?? const []).isEmpty ? tr('client_migration.none') : linksByClient[id]!.join(', ')}',
                        style: textTheme.bodySmall,
                      ),
                      Text('${tr('client_migration.invoices')}: ${invoicesByClient[id] ?? 0}', style: textTheme.bodySmall),
                    ],
                  ),
                ),
              if (plan.newProfile != null) ...[
                const SizedBox(height: 4),
                Text(tr('client_migration.profile', namedArgs: {'name': plan.newProfile!.party.name}), style: textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              Text(tr('client_migration.safe'), style: textTheme.bodySmall?.copyWith(color: mac.tertiaryLabel)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _running ? null : _later, child: Text(tr('client_migration.later'))),
        FilledButton(onPressed: _running ? null : _apply, child: Text(tr('client_migration.apply'))),
      ],
    );
  }
}
