import 'package:flutter/material.dart';

import 'data/db_key.dart';
import 'data/local_store.dart';
import 'shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PocketSenseApp());
}

class PocketSenseApp extends StatelessWidget {
  const PocketSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Sense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF4F46E5),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF818CF8),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const Boot(),
    );
  }
}

/// Opens the on-device database behind the splash, then shows the app. If the
/// database can't be opened, says so instead of running without data.
class Boot extends StatefulWidget {
  const Boot({super.key});

  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  late Future<void> _opening = _open();

  Future<void> _open() => LocalStore.open();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _opening,
      builder: (context, snap) {
        if (snap.hasError) {
          return StartupError(
            error: snap.error!,
            onRetry: () => setState(() => _opening = _open()),
            onErase: snap.error is DbKeyLost ? () => setState(() => _opening = LocalStore.eraseAll().then((_) => _open())) : null,
          );
        }
        if (snap.connectionState != ConnectionState.done) return const _Splash();
        return const Shell();
      },
    );
  }
}

class StartupError extends StatelessWidget {
  const StartupError({super.key, required this.error, required this.onRetry, this.onErase});

  final Object error;
  final VoidCallback onRetry;

  /// Offered only when the data is unrecoverable ([DbKeyLost]).
  final VoidCallback? onErase;

  Future<void> _confirmErase(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Erase all data?'),
        content: const Text('Everything stored in Pocket Sense on this device is deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Erase'),
          ),
        ],
      ),
    );
    if (ok == true) onErase!();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                Text("Couldn't open your data", style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: const Text('Try again')),
                if (onErase != null) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: () => _confirmErase(context), child: const Text('Erase and start over')),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Matches the native Android splash background.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Center(child: Image.asset('assets/splash_icon.png', width: 120, height: 120)),
      );
}
