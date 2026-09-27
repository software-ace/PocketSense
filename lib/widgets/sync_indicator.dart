import 'package:flutter/material.dart';

import '../data/sync_controller.dart';

/// App-bar cloud icon showing whether local changes have reached Supabase.
/// Tap for details and a manual "Sync now".
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncController.instance;
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: sync.status,
      builder: (context, s, _) {
        final scheme = Theme.of(context).colorScheme;
        final Widget icon = switch (s.state) {
          SyncState.syncing => const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SyncState.offline => Icon(Icons.cloud_off_outlined, color: scheme.outline),
          SyncState.error => Icon(Icons.sync_problem_rounded, color: scheme.error),
          SyncState.idle when s.pending > 0 => const Icon(Icons.cloud_upload_outlined),
          SyncState.idle => Icon(Icons.cloud_done_outlined, color: scheme.outline),
        };
        return IconButton(
          tooltip: _headline(s),
          onPressed: () => _showDetails(context),
          icon: Badge(
            isLabelVisible: s.pending > 0 && s.state != SyncState.syncing,
            label: Text('${s.pending}'),
            child: icon,
          ),
        );
      },
    );
  }

  static String _headline(SyncStatus s) => switch (s.state) {
        SyncState.syncing => 'Syncing…',
        SyncState.offline => 'Offline — changes saved on this device',
        SyncState.error => 'Sync problem',
        SyncState.idle when s.pending > 0 => '${s.pending} change${s.pending == 1 ? '' : 's'} waiting to upload',
        SyncState.idle => 'All changes synced',
      };

  void _showDetails(BuildContext context) {
    final sync = SyncController.instance;
    showDialog<void>(
      context: context,
      builder: (ctx) => ValueListenableBuilder<SyncStatus>(
        valueListenable: sync.status,
        builder: (ctx, s, _) {
          final theme = Theme.of(ctx);
          final last = s.lastSynced;
          return AlertDialog(
            title: Text(_headline(s)),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(last == null ? 'Not synced yet this session.' : 'Last synced ${TimeOfDay.fromDateTime(last).format(ctx)}.'),
              if (s.pending > 0) ...[
                const SizedBox(height: 8),
                Text('${s.pending} local change${s.pending == 1 ? ' is' : 's are'} queued and will upload automatically.'),
              ],
              if (s.error != null && s.state != SyncState.idle) ...[
                const SizedBox(height: 12),
                Text(s.error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              ],
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              FilledButton.icon(
                onPressed: s.state == SyncState.syncing ? null : sync.syncNow,
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sync now'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Reloads a tab whenever local data changes, including changes pulled from
/// the server. Tabs sit in an IndexedStack and would otherwise show stale data.
mixin SyncAware<T extends StatefulWidget> on State<T> {
  void onDataChanged();

  void _listener() {
    if (mounted) onDataChanged();
  }

  @override
  void initState() {
    super.initState();
    SyncController.instance.dataChanged.addListener(_listener);
  }

  @override
  void dispose() {
    SyncController.instance.dataChanged.removeListener(_listener);
    super.dispose();
  }

  /// For RefreshIndicator: pull-to-refresh now actually talks to the server.
  Future<void> syncAndReload(Future<void> Function() load) async {
    await SyncController.instance.syncNow();
    if (mounted) await load();
  }
}
