import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/local_store.dart';
import '../settings/app_settings.dart';
import 'identity.dart';
import 'sync_node.dart';

/// A Pocket Sense seen on the local network.
class NearbyDevice {
  NearbyDevice(this.id, this.name, this.address, this.port, this.seen);
  final String id;

  /// Only sent while that device's pairing screen is open.
  final String? name;
  final InternetAddress address;
  final int port;
  final DateTime seen;
}

enum PeerState { syncing, synced, unreachable, needsUpdate, notPaired, failed }

/// Runs sync while the app is open and sync is on: the [SyncNode] server,
/// discovery over UDP multicast, and syncing with every paired device at
/// start, on resume, when one shows up, and shortly after each change.
///
/// ponytail: foreground only. Two phones sync when both have the app open;
/// an Android foreground service would lift that if it proves a problem.
class SyncService {
  SyncService._();
  static final instance = SyncService._();

  // Link-local multicast: never routed off the network, and Wi-Fi access
  // points flood it rather than filter it. Same group as LocalSend uses,
  // a different port.
  static final _group = InternetAddress('224.0.0.167');
  static const _discoveryPort = SyncNode.defaultPort;
  static const _multicastLock = MethodChannel('pocketsense/multicast');

  SyncNode? _node;
  RawDatagramSocket? _udp;
  LocalStore? _store;
  Timer? _debounce;
  Timer? _pairingQueries;
  bool _syncing = false;
  bool _again = false;

  final nearby = ValueNotifier<Map<String, NearbyDevice>>({});
  final peers = ValueNotifier<List<Peer>>([]);
  final states = ValueNotifier<Map<String, PeerState>>({});
  final busy = ValueNotifier(false);

  /// Rows that came in from a peer, for a short note in the UI.
  final arrivals = StreamController<({String peer, int changes})>.broadcast();

  /// A device that asked to pair with this one has been paired.
  final pairedHere = StreamController<Peer>.broadcast();

  bool get running => _node != null;
  String? get id => _node?.identity.id;

  static String defaultName() => Platform.isAndroid ? 'Android' : Platform.localHostname;

  /// The name other devices see this one by.
  String get name {
    final n = AppSettings.sync.value.name.trim();
    return n.isEmpty ? defaultName() : n;
  }

  /// Starts if sync is on. Safe to call again.
  Future<void> start() async {
    if (running || !AppSettings.sync.value.enabled) return;
    final identity = await SyncIdentity.obtain();
    final node = SyncNode(identity: identity, store: LocalStore.instance, name: name)..onPaired = (peer) {
      pairedHere.add(peer);
      _reloadPeers();
    };
    await node.start();
    _node = node;
    _store = await LocalStore.instance();
    _store!.changes.addListener(_onLocalChange);
    await _reloadPeers();
    await _startDiscovery();
    unawaited(syncAll());
  }

  Future<void> stop() async {
    _debounce?.cancel();
    _pairingQueries?.cancel();
    _store?.changes.removeListener(_onLocalChange);
    _store = null;
    await _stopDiscovery();
    await _node?.stop();
    _node = null;
    nearby.value = {};
    states.value = {};
  }

  Future<void> setEnabled(bool on) async {
    await AppSettings.setSync(enabled: on);
    on ? await start() : await stop();
  }

  Future<void> rename(String name) async {
    await AppSettings.setSync(name: name);
    _node?.name = name;
  }

  /// Back in the foreground: the network may have changed while away.
  Future<void> resumed() async {
    if (!running) return start();
    await _stopDiscovery();
    await _startDiscovery();
    await syncAll();
  }

  Future<void> _reloadPeers() async {
    final s = _store;
    if (s != null) peers.value = await Peer.all(s);
  }

  void _onLocalChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncAll);
  }

  void _setState(String peerId, PeerState state) => states.value = {...states.value, peerId: state};

  // ── Discovery ────────────────────────────────────────────────────────

  Future<void> _startDiscovery() async {
    try {
      // Android drops multicast to save battery unless an app holds a lock.
      if (Platform.isAndroid) await _multicastLock.invokeMethod('acquire');
      final udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort, reuseAddress: true);
      udp.joinMulticast(_group);
      udp.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = udp.receive();
        if (d != null) _onPacket(d);
      });
      _udp = udp;
      _announce(query: true);
    } catch (e) {
      // No network yet. Paired devices are still tried at their last address.
      debugPrint('sync discovery: $e');
    }
  }

  Future<void> _stopDiscovery() async {
    _udp?.close();
    _udp = null;
    try {
      if (Platform.isAndroid) await _multicastLock.invokeMethod('release');
    } catch (_) {}
  }

  /// Says "Pocket Sense is here" to [to], or to everyone. [query] asks
  /// everyone to answer. The name goes out only while pairing.
  void _announce({bool query = false, InternetAddress? to}) {
    final node = _node;
    if (node == null) return;
    final msg = {
      'app': 'pocketsense',
      'v': SyncNode.protocol,
      'id': node.identity.id,
      'port': node.port,
      if (node.onPairRequest != null) 'name': node.name,
      if (query) 'q': 1,
    };
    try {
      _udp?.send(utf8.encode(jsonEncode(msg)), to ?? _group, _discoveryPort);
    } catch (_) {}
  }

  void _onPacket(Datagram d) {
    final Object? m;
    try {
      m = jsonDecode(utf8.decode(d.data));
    } catch (_) {
      return;
    }
    if (m is! Map || m['app'] != 'pocketsense' || m['id'] is! String || m['port'] is! int) return;
    final id = m['id'] as String;
    if (id == this.id || !SyncNode.isLocal(d.address)) return;
    if (m['q'] == 1) _announce(to: d.address);
    final name = m['name'];
    final before = nearby.value[id];
    nearby.value = {
      ...nearby.value,
      id: NearbyDevice(id, name is String ? (name.length > 40 ? name.substring(0, 40) : name) : null, d.address, m['port'] as int,
          DateTime.now()),
    };
    // A paired device just appeared, or moved: catch up with it.
    final moved = before == null || before.address != d.address || before.port != m['port'];
    if (moved && peers.value.any((p) => p.id == id)) unawaited(syncAll());
  }

  // ── Pairing ──────────────────────────────────────────────────────────

  /// While set, this device shows its name to others and accepts pairing
  /// requests through [onRequest]. Pass null when the pairing screen closes.
  void setPairing(Future<bool> Function(PairRequest request)? onRequest) {
    _node?.onPairRequest = onRequest;
    _pairingQueries?.cancel();
    if (onRequest == null) return;
    _announce(query: true);
    // Keeps the list fresh while the screen is open.
    _pairingQueries = Timer.periodic(const Duration(seconds: 3), (_) => _announce(query: true));
  }

  Future<({Peer peer, int theirEntries})> pair(NearbyDevice device,
      {required Future<bool> Function(String code, String peerName) confirm}) async {
    final node = _node;
    if (node == null) throw SyncFailure(SyncProblem.failed, 'sync is off');
    final result = await node.pair(device.address, device.port, confirm: confirm);
    await _reloadPeers();
    return result;
  }

  /// Replaces everything here with [peer]'s data: empties this device
  /// without telling anyone, then takes everything the peer has.
  Future<void> replaceWith(Peer peer) async {
    final s = await LocalStore.instance();
    await s.wipeSyncedData();
    await s.db.update('peers', {'received_seq': 0, 'sent_seq': 0}, where: 'id = ?', whereArgs: [peer.id]);
    await syncAll();
  }

  Future<void> unpair(Peer peer) async {
    final s = await LocalStore.instance();
    await s.db.delete('peers', where: 'id = ?', whereArgs: [peer.id]);
    states.value = {...states.value}..remove(peer.id);
    await _reloadPeers();
  }

  // ── Sync ─────────────────────────────────────────────────────────────

  /// Syncs with every paired device that answers. Runs one at a time; a
  /// call while running makes it go round once more.
  Future<void> syncAll() async {
    if (_node == null) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    busy.value = true;
    try {
      do {
        _again = false;
        final s = _store;
        if (s == null) break;
        for (final p in await Peer.all(s)) {
          await _syncOne(p);
        }
      } while (_again && _node != null);
    } finally {
      _syncing = false;
      busy.value = false;
      await _reloadPeers();
    }
  }

  Future<void> _syncOne(Peer peer) async {
    final node = _node;
    if (node == null) return;
    final near = nearby.value[peer.id];
    final targets = <(InternetAddress, int)>[
      if (near != null) (near.address, near.port),
      if (peer.lastAddress != null && peer.lastAddress != near?.address.address)
        (InternetAddress(peer.lastAddress!), SyncNode.defaultPort),
    ];
    if (targets.isEmpty) return _setState(peer.id, PeerState.unreachable);
    _setState(peer.id, PeerState.syncing);
    for (final (address, port) in targets) {
      try {
        final n = await node.syncWith(peer, address, port);
        _setState(peer.id, PeerState.synced);
        if (n > 0) arrivals.add((peer: peer.name, changes: n));
        return;
      } on SyncFailure catch (e) {
        switch (e.problem) {
          case SyncProblem.unreachable:
            continue;
          case SyncProblem.versionMismatch:
            return _setState(peer.id, PeerState.needsUpdate);
          case SyncProblem.notPaired:
            return _setState(peer.id, PeerState.notPaired);
          default:
            return _setState(peer.id, PeerState.failed);
        }
      } catch (e) {
        debugPrint('sync with ${peer.name}: $e');
        return _setState(peer.id, PeerState.failed);
      }
    }
    _setState(peer.id, PeerState.unreachable);
  }
}
