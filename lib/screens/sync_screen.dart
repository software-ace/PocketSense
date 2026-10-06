import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../data/local_store.dart';
import '../l10n/l10n.dart';
import '../settings/app_settings.dart';
import '../sync/sync_node.dart';
import '../sync/sync_service.dart';

/// Settings → Sync: on/off, this device's name, pairing, and the paired
/// devices with how their last sync went.
class SyncSection extends StatelessWidget {
  const SyncSection({super.key});

  Future<void> _toggle(BuildContext context, bool on) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      final name = await askDeviceName(context);
      if (name == null) return;
      await SyncService.instance.rename(name);
    }
    try {
      await SyncService.instance.setEnabled(on);
    } catch (e) {
      // E.g. the keyring, where this device's sync key lives, is locked.
      await SyncService.instance.setEnabled(false);
      messenger.showSnackBar(SnackBar(content: Text(l.syncStartFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final service = SyncService.instance;
    return ValueListenableBuilder(
      valueListenable: AppSettings.sync,
      builder: (context, sync, _) => Column(children: [
        SwitchListTile(
          secondary: const Icon(Icons.sync),
          title: Text(l.syncToggle),
          subtitle: Text(l.syncToggleSubtitle),
          isThreeLine: true,
          value: sync.enabled,
          onChanged: (on) => _toggle(context, on),
        ),
        if (sync.enabled) ...[
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(l.syncDeviceName),
            subtitle: Text(service.name),
            onTap: () async {
              final name = await askDeviceName(context);
              if (name != null) await service.rename(name);
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_link),
            title: Text(l.syncPairDevice),
            subtitle: Text(l.syncPairDeviceSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PairScreen())),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([service.peers, service.states]),
            builder: (context, _) => Column(children: [
              for (final p in service.peers.value) _PeerTile(peer: p, state: service.states.value[p.id]),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// Asks for this device's name, prefilled; null if cancelled.
Future<String?> askDeviceName(BuildContext context) async {
  final l = context.l10n;
  final controller = TextEditingController(text: SyncService.instance.name);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.syncDeviceName),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        decoration: InputDecoration(helperText: l.syncDeviceNameHint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(l.save)),
      ],
    ),
  );
  controller.dispose();
  return name?.trim();
}

class _PeerTile extends StatelessWidget {
  const _PeerTile({required this.peer, required this.state});
  final Peer peer;
  final PeerState? state;

  String _status(AppLocalizations l) {
    final last = peer.lastSync;
    final when = last == null ? null : DateFormat.MMMd().add_jm().format(last.toLocal());
    final problem = switch (state) {
      PeerState.syncing => l.syncStateSyncing,
      PeerState.unreachable => l.syncStateUnreachable,
      PeerState.needsUpdate => l.syncStateNeedsUpdate,
      PeerState.notPaired => l.syncStateNotPaired,
      PeerState.failed => l.syncStateFailed,
      PeerState.synced || null => null,
    };
    if (problem == null) return when == null ? l.syncStateNever : l.syncStateSynced(when);
    return when == null || state == PeerState.syncing ? problem : l.syncLastSeen(problem, when);
  }

  Future<void> _actions(BuildContext context) async {
    final l = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(peer.name, style: Theme.of(ctx).textTheme.titleMedium)),
          ListTile(leading: const Icon(Icons.sync), title: Text(l.syncNow), onTap: () => Navigator.pop(ctx, 'sync')),
          ListTile(leading: const Icon(Icons.link_off), title: Text(l.syncUnpair), onTap: () => Navigator.pop(ctx, 'unpair')),
        ]),
      ),
    );
    if (!context.mounted) return;
    if (action == 'sync') unawaited(SyncService.instance.syncAll());
    if (action == 'unpair') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.syncUnpairTitle(peer.name)),
          content: Text(l.syncUnpairBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.syncUnpair)),
          ],
        ),
      );
      if (ok == true) await SyncService.instance.unpair(peer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final trouble = state == PeerState.needsUpdate || state == PeerState.notPaired || state == PeerState.failed;
    return ListTile(
      leading: Icon(trouble ? Icons.sync_problem : Icons.devices, color: trouble ? Theme.of(context).colorScheme.error : null),
      title: Text(peer.name),
      subtitle: Text(_status(l)),
      trailing: state == PeerState.syncing
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : null,
      onTap: () => _actions(context),
    );
  }
}

/// Finds Pocket Sense on other devices and pairs with one. Both devices
/// open this screen; one taps the other, and both users check that the
/// two screens show the same 6-digit code.
class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _service = SyncService.instance;
  late final Timer _tick;
  late final StreamSubscription<Peer> _pairedHere;
  final _opened = DateTime.now();
  bool _pairing = false;

  @override
  void initState() {
    super.initState();
    _service.setPairing(_incoming);
    // The other device tapped this one, and both said the codes match.
    _pairedHere = _service.pairedHere.stream.listen((peer) {
      if (!mounted) return;
      _toast(context.l10n.syncPairedWith(peer.name));
      Navigator.of(context).pop();
    });
    // Redraws so devices that left drop off, and the hint shows in time.
    _tick = Timer.periodic(const Duration(seconds: 2), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick.cancel();
    _pairedHere.cancel();
    _service.setPairing(null);
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// Another device tapped this one: show the code, ask if it matches.
  Future<bool> _incoming(PairRequest request) async {
    if (!mounted || _pairing) return false;
    final nav = Navigator.of(context);
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CodeDialog(title: ctx.l10n.syncIncomingTitle(request.name), name: request.name, code: request.code),
    );
    // The other device gave up: close the prompt.
    unawaited(request.cancelled.future.then((_) {
      if (route.isActive) nav.removeRoute(route);
    }));
    return await nav.push(route) ?? false;
  }

  Future<void> _pairWith(NearbyDevice device) async {
    final l = context.l10n;
    final nav = Navigator.of(context);
    setState(() => _pairing = true);
    final waiting = ValueNotifier<String>(l.syncConnecting);
    final progress = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: ValueListenableBuilder(valueListenable: waiting, builder: (_, text, _) => Text(text))),
          ]),
        ),
      ),
    );
    unawaited(nav.push(progress));
    try {
      final result = await _service.pair(device, confirm: (code, name) async {
        final ok = await nav.push(DialogRoute<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _CodeDialog(title: l.syncCodeTitle, name: name, code: code),
        ));
        waiting.value = l.syncWaitingFor(name);
        return ok ?? false;
      });
      if (progress.isActive) nav.removeRoute(progress);
      if (!mounted) return;
      await _firstSync(result.peer, result.theirEntries);
      if (!mounted) return;
      _toast(l.syncPairedWith(result.peer.name));
      nav.pop();
    } on SyncFailure catch (e) {
      if (progress.isActive) nav.removeRoute(progress);
      if (mounted) _toast(_describe(l, e));
    } catch (e) {
      if (progress.isActive) nav.removeRoute(progress);
      if (mounted) _toast(l.syncErrFailed('$e'));
    } finally {
      waiting.dispose();
      if (mounted) setState(() => _pairing = false);
    }
  }

  /// Combine both devices' data, unless both have some and the user would
  /// rather take the other's. Offered only for a first peer: replacing here
  /// wouldn't reach devices paired before.
  Future<void> _firstSync(Peer peer, int theirEntries) async {
    final l = context.l10n;
    final mine = await SyncNode.entryCount(await LocalStore.instance());
    final others = _service.peers.value.where((p) => p.id != peer.id);
    var replace = false;
    if (mine > 0 && theirEntries > 0 && others.isEmpty && mounted) {
      replace = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Text(l.syncFirstTitle),
              content: Text(l.syncFirstBody(peer.name)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.syncReplace)),
                FilledButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.syncCombine)),
              ],
            ),
          ) ??
          false;
      if (replace && mounted) {
        replace = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l.syncReplaceTitle),
                content: Text(l.syncReplaceBody(peer.name)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(l.syncReplaceAction),
                  ),
                ],
              ),
            ) ??
            false;
      }
    }
    replace ? await _service.replaceWith(peer) : await _service.syncAll();
  }

  static String _describe(AppLocalizations l, SyncFailure e) => switch (e.problem) {
        SyncProblem.unreachable => l.syncErrUnreachable,
        SyncProblem.declined || SyncProblem.notPaired => l.syncErrDeclined,
        SyncProblem.busy => l.syncErrBusy,
        SyncProblem.versionMismatch => l.syncErrVersion,
        SyncProblem.codeMismatch => l.syncErrCode,
        SyncProblem.failed => l.syncErrFailed(e.detail ?? ''),
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final paired = {for (final p in _service.peers.value) p.id};
    return Scaffold(
      appBar: AppBar(title: Text(l.syncPairDevice)),
      body: ValueListenableBuilder(
        valueListenable: _service.nearby,
        builder: (context, nearby, _) {
          final now = DateTime.now();
          final devices = nearby.values
              .where((d) => d.name != null && now.difference(d.seen) < const Duration(seconds: 10))
              .toList()
            ..sort((a, b) => a.name!.compareTo(b.name!));
          final hint = now.difference(_opened) > const Duration(seconds: 10);
          return ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
            ListTile(
              leading: const Icon(Icons.wifi_tethering),
              title: Text(l.syncVisibleAs(_service.name)),
              subtitle: Text(l.syncPairHelp),
            ),
            const Divider(),
            for (final d in devices)
              ListTile(
                leading: const Icon(Icons.devices),
                title: Text(d.name!),
                subtitle: Text(d.address.address),
                trailing: paired.contains(d.id) ? Chip(label: Text(l.syncPairedTag)) : const Icon(Icons.chevron_right),
                enabled: !_pairing,
                onTap: () => _pairWith(d),
              ),
            if (devices.isEmpty) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Center(child: Text(l.syncLooking, style: theme.textTheme.bodyLarge)),
              if (hint)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.syncNotFoundHint, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
                ),
            ],
          ]);
        },
      ),
    );
  }
}

/// The 6-digit code, large and grouped 3 + 3, with Match / Don't match.
class _CodeDialog extends StatelessWidget {
  const _CodeDialog({required this.title, required this.name, required this.code});
  final String title;
  final String name;
  final String code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final grouped = '${code.substring(0, 3)} ${code.substring(3)}';
    return AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(l.syncCodeBody(name)),
        const SizedBox(height: 16),
        Semantics(
          // Read out digit by digit, not as "four hundred eighty-two thousand…".
          label: code.split('').join(' '),
          excludeSemantics: true,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(grouped,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.syncCodesDiffer)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.syncCodesMatch)),
      ],
    );
  }
}

/// App-bar button while sync is on with a paired device: shows syncing or
/// trouble, and syncs now when tapped.
class SyncButton extends StatelessWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SyncService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([AppSettings.sync, service.peers, service.states, service.busy]),
      builder: (context, _) {
        if (!AppSettings.sync.value.enabled || service.peers.value.isEmpty) return const SizedBox.shrink();
        final trouble = service.states.value.values
            .any((s) => s == PeerState.needsUpdate || s == PeerState.notPaired || s == PeerState.failed);
        return IconButton(
          tooltip: context.l10n.syncNow,
          onPressed: service.busy.value ? null : service.syncAll,
          icon: service.busy.value
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(trouble ? Icons.sync_problem : Icons.sync,
                  color: trouble ? Theme.of(context).colorScheme.error : null),
        );
      },
    );
  }
}
