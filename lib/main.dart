import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data/session.dart';
import 'data/sync_controller.dart';
import 'screens/auth_screen.dart';
import 'shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Restores a saved session from device storage, so a signed-in user boots
  // straight into their cached data even fully offline.
  await Supabase.initialize(url: Config.supabaseUrl, publishableKey: Config.supabasePublishableKey);

  // Offline-first spine: each account's local mirror syncs on every local
  // write, app resume and connectivity change (see SyncController). Failures
  // never block the UI; they surface through the sync indicator instead.
  final sync = SyncController.instance;
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
      home: const AuthGate(),
    );
  }
}

/// Routes on auth state: signed out → [AuthScreen]; signed in → open that
/// account's data, show the splash until its first sync (max 5 s), then the
/// app. Keyed by user id so switching accounts rebuilds every screen.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  String? _userId = Supabase.instance.client.auth.currentUser?.id;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((s) => _onUser(s.session?.user.id));
    passwordResetInProgress.addListener(_rebuild);
    // After the first frame: _onUser calls setState.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onUser(_userId));
  }

  @override
  void dispose() {
    _sub.cancel();
    passwordResetInProgress.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _onUser(String? id) async {
    if (!mounted || (id == DataSession.userId && (id == null || _ready))) return;
    setState(() {
      _userId = id;
      _ready = false;
    });
    if (id == null) {
      await DataSession.end();
      return;
    }
    await DataSession.start(id);
    try {
      await SyncController.instance.ready.timeout(const Duration(seconds: 5));
    } catch (_) {
      // Slow or offline: go in with cached data.
    }
    if (mounted && _userId == id) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final id = _userId;
    if (id == null || passwordResetInProgress.value) return const AuthScreen();
    if (!_ready) return const _Splash();
    return Shell(key: ValueKey(id));
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
