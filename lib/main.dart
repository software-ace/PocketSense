import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/local_store.dart';
import 'data/sync_controller.dart';
import 'data/sync_engine.dart';
import 'shell.dart';

/// Completes when the first sync round-trip finishes (or fails). Screens await
/// this so they never render an empty DB that is merely mid-seed.
final Completer<void> initialSyncDone = Completer<void>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabasePublishableKey);

  // Offline-first spine: open the local mirror, seed it from remote once, then
  // keep it fresh on every local write, app resume and connectivity change.
  // Failures never block boot — the app must show cached data even offline;
  // they surface through the sync indicator instead.
  final store = await LocalStore.instance();
  await store.initSchema();
  await store.loadWatermarks();
  final sync = SyncController.instance..attach(SyncEngine(store, Supabase.instance.client));
  store.onAppend = sync.onLocalWrite;
  unawaited(
    sync.syncNow().whenComplete(() {
      if (!initialSyncDone.isCompleted) initialSyncDone.complete();
    }),
  );
  _watchConnectivity(sync);
  // Returning to the app is the moment the user expects fresh data.
  AppLifecycleListener(onResume: () => unawaited(sync.syncNow()));

  runApp(const PocketSenseApp());
}

void _watchConnectivity(SyncController sync) {
  Connectivity().onConnectivityChanged.listen((results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online) unawaited(sync.syncNow());
  });
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
      home: const SplashGate(),
    );
  }
}

/// Shows a branded splash until the first sync completes, then transitions
/// to the main shell. Matches the native Android splash background.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _ready = false;

  static const _bgColor = Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    _listenForReady();
  }

  Future<void> _listenForReady() async {
    try {
      await initialSyncDone.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      // Timeout or error — proceed anyway, app works offline.
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const Shell();
    return Scaffold(
      backgroundColor: _bgColor,
      body: Center(
        child: Image.asset(
          'assets/splash_icon.png',
          width: 120,
          height: 120,
        ),
      ),
    );
  }
}
