import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/daily_snapshot_service.dart';
import '../../core/services/deletion_journal_service.dart';
import '../../core/services/pocketbase_sync_service.dart';
import '../../core/services/snapshot_diff_service.dart';

/// Local snapshot history and the deletion journal — the two places to look
/// when data has vanished.
class BackupHistoryScreen extends StatefulWidget {
  const BackupHistoryScreen({super.key});

  @override
  State<BackupHistoryScreen> createState() => _BackupHistoryScreenState();
}

class _BackupHistoryScreenState extends State<BackupHistoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('backup_history.title')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tr('backup_history.tab_snapshots')),
            Tab(text: tr('backup_history.tab_journal')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_SnapshotsTab(), _JournalTab()],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Snapshots
// ─────────────────────────────────────────────────────────────────────────────

class _SnapshotsTab extends StatefulWidget {
  const _SnapshotsTab();

  @override
  State<_SnapshotsTab> createState() => _SnapshotsTabState();
}

class _SnapshotsTabState extends State<_SnapshotsTab> {
  List<SnapshotInfo> _snapshots = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() => _snapshots = context.read<DailySnapshotService>().listSnapshots());
  }

  Future<void> _createNow() async {
    setState(() => _busy = true);
    try {
      await context.read<DailySnapshotService>().takeSnapshotNow();
      if (!mounted) return;
      _reload();
      _toast(context, tr('backup_history.snapshot_created'));
    } catch (e) {
      if (mounted) _toast(context, tr('backup_history.snapshot_failed', namedArgs: {'error': '$e'}), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFolder() async {
    final path = context.read<DailySnapshotService>().directoryPath;
    if (path == null) return;
    await launchUrl(Uri.file(path));
  }

  Future<void> _compare(SnapshotInfo snapshot) async {
    final snapshotService = context.read<DailySnapshotService>();
    final diffService = context.read<SnapshotDiffService>();

    final data = await snapshotService.readSnapshot(snapshot.path);
    if (!mounted) return;

    if (data == null) {
      _toast(context, tr('backup_history.snapshot_unreadable'), isError: true);
      return;
    }

    final diff = diffService.compare(data, snapshotPath: snapshot.path, snapshotDate: snapshot.date);
    if (!mounted) return;

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _DiffScreen(diff: diff)));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final snapshotService = context.read<DailySnapshotService>();

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: Text(tr('backup_history.create_now')),
                subtitle: Text(tr('backup_history.create_now_desc')),
                trailing: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
                onTap: _busy ? null : _createNow,
              ),
              if (snapshotService.directoryPath != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: Text(tr('backup_history.open_folder')),
                  subtitle: Text(snapshotService.directoryPath!, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: _openFolder,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _snapshots.isEmpty
              ? Center(child: Text(tr('backup_history.no_snapshots')))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _snapshots.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final snapshot = _snapshots[index];
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(DateFormat.yMMMMd(context.locale.toString()).format(snapshot.date)),
                      subtitle: Text('${(snapshot.sizeBytes / 1024).toStringAsFixed(1)} kB'),
                      trailing: TextButton(onPressed: () => _compare(snapshot), child: Text(tr('backup_history.compare'))),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diff detail
// ─────────────────────────────────────────────────────────────────────────────

class _DiffScreen extends StatefulWidget {
  final SnapshotDiff diff;

  const _DiffScreen({required this.diff});

  @override
  State<_DiffScreen> createState() => _DiffScreenState();
}

class _DiffScreenState extends State<_DiffScreen> {
  late final Set<String> _selectedDays = widget.diff.missingDays.map((d) => d.key).toSet();
  bool _pushToServer = true;
  bool _restoring = false;

  Future<void> _restore() async {
    setState(() => _restoring = true);

    final syncService = context.read<PocketBaseSyncService?>();
    final result = await context.read<SnapshotDiffService>().restoreMissing(
      widget.diff,
      onlyDays: _selectedDays,
      syncService: _pushToServer ? syncService : null,
    );

    if (!mounted) return;
    setState(() => _restoring = false);

    if (result.hasError) {
      _toast(context, tr('backup_history.restore_failed', namedArgs: {'error': result.error!}), isError: true);
      return;
    }

    _toast(context, tr('backup_history.restore_done', namedArgs: {'count': '${result.total}'}));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.diff;
    final days = diff.missingDays;
    final syncService = context.read<PocketBaseSyncService?>();
    final canPush = syncService != null && syncService.isSignedIn;

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat.yMMMMd(context.locale.toString()).format(diff.snapshotDate))),
      body: !diff.hasLoss
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 56, color: Colors.green.shade600),
                    const SizedBox(height: 12),
                    Text(tr('backup_history.no_loss'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      tr('backup_history.added_since', namedArgs: {'count': '${diff.addedTimeEntries}'}),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('backup_history.loss_detected', namedArgs: {'count': '${diff.totalMissing}'}),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr('backup_history.loss_detail', namedArgs: {
                            'projects': '${diff.missingProjects.length}',
                            'tasks': '${diff.missingTasks.length}',
                            'entries': '${diff.missingTimeEntries.length}',
                          }),
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (days.isNotEmpty) ...[
                  Text(tr('backup_history.missing_days'), style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  ...days.map(
                    (day) => CheckboxListTile(
                      value: _selectedDays.contains(day.key),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          _selectedDays.add(day.key);
                        } else {
                          _selectedDays.remove(day.key);
                        }
                      }),
                      title: Text(DateFormat.yMMMMEEEEd(context.locale.toString()).format(day.day)),
                      subtitle: Text(
                        tr('backup_history.day_summary', namedArgs: {
                          'count': '${day.entries.length}',
                          'duration': _formatDuration(day.totalSeconds),
                        }),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                if (canPush)
                  SwitchListTile(
                    value: _pushToServer,
                    onChanged: (v) => setState(() => _pushToServer = v),
                    title: Text(tr('backup_history.push_to_server')),
                    subtitle: Text(tr('backup_history.push_to_server_desc')),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _restoring || (_selectedDays.isEmpty && days.isNotEmpty) ? null : _restore,
                  icon: _restoring
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.restore),
                  label: Text(tr('backup_history.restore')),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deletion journal
// ─────────────────────────────────────────────────────────────────────────────

class _JournalTab extends StatefulWidget {
  const _JournalTab();

  @override
  State<_JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends State<_JournalTab> {
  List<JournalEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await context.read<DeletionJournalService>().readEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _restore(JournalEntry entry) async {
    final syncService = context.read<PocketBaseSyncService?>();
    final ok = await context.read<SnapshotDiffService>().restoreJournalledRecord(
      entry.collection,
      entry.payload,
      syncService: syncService,
    );

    if (!mounted) return;
    _toast(
      context,
      ok ? tr('backup_history.journal_restored') : tr('backup_history.journal_restore_failed'),
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_entries.isEmpty) return Center(child: Text(tr('backup_history.no_deletions')));

    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return ListTile(
          leading: Icon(_iconFor(entry.source), color: _colorFor(entry.source, context)),
          title: Text(_describe(entry)),
          subtitle: Text(
            '${DateFormat.yMd(context.locale.toString()).add_Hm().format(entry.timestamp)} · ${tr('backup_history.source_${entry.source.name}')}',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.restore),
            tooltip: tr('backup_history.restore'),
            onPressed: () => _restore(entry),
          ),
        );
      },
    );
  }

  /// Show whatever identifies the record to a human — the name, or for a time
  /// entry the day it was tracked on. The raw id is useless here.
  String _describe(JournalEntry entry) {
    final payload = entry.payload;
    final name = payload['name'];
    if (name is String && name.isNotEmpty) return name;

    final start = payload['startTime'];
    if (start is String) {
      final date = DateTime.tryParse(start);
      if (date != null) return DateFormat.yMd(context.locale.toString()).add_Hm().format(date);
    }
    return entry.itemId;
  }

  IconData _iconFor(DeleteSource source) => switch (source) {
    DeleteSource.userAction => Icons.person_outline,
    DeleteSource.cascade => Icons.account_tree_outlined,
    DeleteSource.syncRealtime => Icons.cloud_sync_outlined,
    DeleteSource.syncReconcile => Icons.cloud_download_outlined,
    DeleteSource.bulkClear => Icons.delete_sweep_outlined,
  };

  /// Deletions the user did not ask for are the ones worth noticing.
  Color? _colorFor(DeleteSource source, BuildContext context) => switch (source) {
    DeleteSource.syncRealtime || DeleteSource.syncReconcile || DeleteSource.bulkClear => Theme.of(context).colorScheme.error,
    _ => null,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  return '${hours}h ${minutes}m';
}

void _toast(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : null),
  );
}
