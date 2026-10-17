import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/db_key.dart';
import '../l10n/l10n.dart';

/// Shown instead of the app when its data can't be opened: by Boot, and by
/// the lock screen when it can't tell whether a PIN is set.
class StartupError extends StatelessWidget {
  const StartupError({super.key, required this.error, required this.onRetry, this.onErase});

  final Object error;
  final VoidCallback onRetry;

  /// Offered only when the data is unrecoverable ([DbKeyLost]).
  final VoidCallback? onErase;

  static String describe(AppLocalizations l, Object error) => switch (error) {
        KeyStoreUnavailable(:final detail) when defaultTargetPlatform == TargetPlatform.android => l.keystoreUnavailableAndroid(detail),
        KeyStoreUnavailable(:final detail) => l.keyringUnavailable(detail),
        DbKeyLost() => l.dbKeyLost,
        _ => '$error',
      };

  Future<void> _confirmErase(BuildContext context) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.eraseAllTitle),
        content: Text(l.eraseAllBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.erase),
          ),
        ],
      ),
    );
    if (ok == true) onErase!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(l.startupErrorTitle, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(describe(l, error), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: Text(l.tryAgain)),
                if (onErase != null) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => _confirmErase(context), child: Text(l.eraseAndStartOver)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
