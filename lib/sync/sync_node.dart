import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show SecretKey;
import 'package:sqflite_sqlcipher/sqflite.dart' show ConflictAlgorithm;

import '../data/local_store.dart';
import 'identity.dart';
import 'merge.dart';

/// A device this one is paired with: a row of the peers table.
class Peer {
  Peer(this.row);
  final Map<String, Object?> row;

  String get id => row['id'] as String;
  String get name => row['name'] as String;
  List<int> get publicKey => base64.decode(row['public_key'] as String);
  int get receivedSeq => row['received_seq'] as int;
  int get sentSeq => row['sent_seq'] as int;
  DateTime? get lastSync => DateTime.tryParse(row['last_sync'] as String? ?? '');
  String? get lastAddress => row['last_addr'] as String?;

  static Future<List<Peer>> all(LocalStore store) async =>
      [for (final r in await store.db.query('peers', orderBy: 'name')) Peer(r)];
}

/// An incoming pairing request, shown to the user on this device.
class PairRequest {
  PairRequest(this.name, this.code);
  final String name;
  final String code;

  /// Completes if the other device gives up first, to close the prompt.
  final cancelled = Completer<void>();
}

/// Why a sync or pairing attempt failed, for the UI.
enum SyncProblem { unreachable, notPaired, versionMismatch, declined, busy, codeMismatch, failed }

class SyncFailure implements Exception {
  SyncFailure(this.problem, [this.detail]);
  final SyncProblem problem;
  final String? detail;

  @override
  String toString() => 'SyncFailure(${problem.name}${detail == null ? '' : ': $detail'})';
}

/// One device's end of sync: a small HTTP server for peers, and the client
/// calls that pair with and sync to them. Every sync message is encrypted
/// and authenticated with the key the two devices share (see
/// [SyncIdentity.sharedKey]); only pairing runs in the clear, and the
/// 6-digit code the users compare is what makes it safe.
class SyncNode {
  SyncNode({required this.identity, required this.store, required this.name});

  static const defaultPort = 47823;
  static const protocol = 1;

  // Comfortably above years of entries; refuse anything bigger unread.
  static const _maxBody = 64 << 20;
  static const _pairTimeout = Duration(minutes: 2);

  final SyncIdentity identity;
  final Future<LocalStore> Function() store;
  String name;

  /// Set while the pairing screen is open: asks the user whether the code
  /// matches. Pairing requests are refused while it's null.
  Future<bool> Function(PairRequest request)? onPairRequest;

  /// A device that asked to pair with this one is now paired.
  void Function(Peer peer)? onPaired;

  HttpServer? _server;
  int get port => _server?.port ?? 0;
  final _keys = <String, SecretKey>{};
  _PairSession? _session;

  /// Listens on [port], or any free port if that one is taken.
  Future<void> start({int port = defaultPort}) async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    } on SocketException {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _server!.listen((req) => _handle(req).catchError((Object _) {}));
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// Home and office networks only. Sync never leaves the local network.
  static bool isLocal(InternetAddress a) {
    if (a.isLoopback || a.isLinkLocal) return true;
    if (a.type != InternetAddressType.IPv4) return false;
    final b = a.rawAddress;
    return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] < 32) || (b[0] == 192 && b[1] == 168);
  }

  /// How much this device holds beyond the starter categories; pairing
  /// uses it to ask whether to combine or replace.
  static Future<int> entryCount(LocalStore s) async {
    var n = 0;
    for (final t in ['transactions', 'budgets', 'recurring_expenses']) {
      n += (await s.db.rawQuery('SELECT count(*) AS n FROM $t')).first['n'] as int;
    }
    return n + ((await s.db.rawQuery("SELECT count(*) AS n FROM categories WHERE uid NOT LIKE 'default:%'")).first['n'] as int);
  }

  Future<SecretKey> _keyFor(String peerId, List<int> publicKey) async =>
      _keys[peerId] ??= await identity.sharedKey(publicKey);

  // ── Server ───────────────────────────────────────────────────────────

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    Future<void> reply(int status, [Object? body]) async {
      res.statusCode = status;
      if (body != null) {
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode(body));
      }
      await res.close();
    }

    final from = req.connectionInfo?.remoteAddress;
    if (from == null || !isLocal(from)) return reply(HttpStatus.forbidden);
    if (req.method != 'POST') return reply(HttpStatus.notFound);
    final Object? body;
    try {
      body = await _readJson(req);
    } catch (_) {
      return reply(HttpStatus.badRequest);
    }
    if (body is! Map) return reply(HttpStatus.badRequest);
    final int status;
    final Object? out;
    try {
      (status, out) = switch (req.uri.path) {
        '/sync' => await _serveSync(body, from),
        '/pair/start' => await _pairStart(body),
        '/pair/nonce' => await _pairNonce(body),
        '/pair/confirm' => await _pairConfirm(body),
        '/pair/cancel' => _pairCancel(body),
        _ => (HttpStatus.notFound, null),
      };
    } on SyncAuthError {
      return reply(HttpStatus.unauthorized);
    } catch (_) {
      // Bad data, or a field of the wrong type.
      return reply(HttpStatus.badRequest);
    }
    return reply(status, out);
  }

  static Future<Object?> _readJson(Stream<List<int>> body) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in body) {
      bytes.add(chunk);
      if (bytes.length > _maxBody) throw const FormatException('too large');
    }
    return jsonDecode(utf8.decode(bytes.takeBytes()));
  }

  Future<(int, Object?)> _serveSync(Map body, InternetAddress from) async {
    final s = await store();
    final row = (await s.db.query('peers', where: 'id = ?', whereArgs: [body['from']])).firstOrNull;
    // Unknown devices learn nothing, not even whether pairing exists.
    if (row == null) return (HttpStatus.unauthorized, null);
    final peer = Peer(row);
    final key = await _keyFor(peer.id, peer.publicKey);
    final msg = await SyncIdentity.open(key, 'sync:${peer.id}>${identity.id}', body['sealed']);
    if (msg is! Map || msg['since'] is! int || msg['challenge'] is! String) throw SyncDataException('request');
    if (msg['v'] != protocol || msg['schema'] != LocalStore.schemaVersion) {
      return (HttpStatus.conflict, {'v': protocol, 'schema': LocalStore.schemaVersion});
    }
    final changes = msg['changes'];
    await Merge.apply(s, changes);
    final since = msg['since'] as int;
    // What the peer asks for is what it already has of ours.
    await s.db.rawUpdate(
        'UPDATE peers SET received_seq = max(received_seq, ?), sent_seq = max(sent_seq, ?), last_sync = ?, last_addr = ? WHERE id = ?',
        [(changes as Map)['up_to'] as int? ?? 0, since, LocalStore.nowIso(), from.address, peer.id]);
    final out = await Merge.changesSince(s, since);
    return (HttpStatus.ok, {
      'sealed': await SyncIdentity.seal(key, 'sync:${identity.id}>${peer.id}', {'changes': out, 'challenge': msg['challenge']}),
    });
  }

  // Pairing, after Bluetooth's numeric comparison. The responder commits to
  // its nonce before seeing the initiator's, so a man in the middle gets one
  // guess in a million at making both screens show the same code.

  Future<(int, Object?)> _pairStart(Map body) async {
    final handler = onPairRequest;
    if (handler == null) return (HttpStatus.forbidden, null);
    if (body['v'] != protocol) return (HttpStatus.conflict, {'v': protocol, 'schema': LocalStore.schemaVersion});
    final pk = base64.decode(body['pk'] as String);
    final id = await SyncIdentity.idOf(pk);
    final active = _session;
    if (active != null && active.peerId != id && DateTime.now().difference(active.started) < _pairTimeout) {
      return (HttpStatus.tooManyRequests, null);
    }
    _endSession();
    final nonce = SyncIdentity.randomBytes(32);
    _session = _PairSession(id, pk, (body['name'] as String? ?? '?').clip(40), nonce);
    return (HttpStatus.ok, {
      'name': name,
      'pk': base64.encode(identity.publicKey),
      'commit': base64.encode(await SyncIdentity.commitment(identity.publicKey, pk, nonce)),
      'entries': await entryCount(await store()),
    });
  }

  Future<(int, Object?)> _pairNonce(Map body) async {
    final session = _session;
    final handler = onPairRequest;
    if (session == null || handler == null || session.peerId != body['id'] || session.request != null) {
      return (HttpStatus.forbidden, null);
    }
    final na = base64.decode(body['nonce'] as String);
    final code = await SyncIdentity.pairingCode(session.peerKey, identity.publicKey, na, session.nonce);
    final request = session.request = PairRequest(session.peerName, code);
    session.decision = handler(request).timeout(_pairTimeout, onTimeout: () => false).catchError((Object _) => false);
    return (HttpStatus.ok, {'nonce': base64.encode(session.nonce)});
  }

  Future<(int, Object?)> _pairConfirm(Map body) async {
    final session = _session;
    if (session == null || session.peerId != body['id'] || session.decision == null) return (HttpStatus.forbidden, null);
    final key = await identity.sharedKey(session.peerKey);
    // Sealed with the shared key: proves it's the device whose code was shown.
    await SyncIdentity.open(key, 'pair:${session.peerId}>${identity.id}', body['sealed']);
    final ok = await session.decision!;
    if (_session != session) return (HttpStatus.gone, null);
    _session = null;
    if (ok) {
      final peer = await _savePeer(session.peerId, session.peerName, session.peerKey);
      onPaired?.call(peer);
    }
    return (HttpStatus.ok, {'sealed': await SyncIdentity.seal(key, 'pair:${identity.id}>${session.peerId}', {'ok': ok})});
  }

  (int, Object?) _pairCancel(Map body) {
    if (_session?.peerId == body['id']) _endSession();
    return (HttpStatus.ok, const {});
  }

  void _endSession() {
    final r = _session?.request;
    if (r != null && !r.cancelled.isCompleted) r.cancelled.complete();
    _session = null;
  }

  Future<Peer> _savePeer(String id, String name, List<int> publicKey, {String? address}) async {
    final s = await store();
    _keys.remove(id);
    // Pairing again starts the watermarks over: re-sending is harmless,
    // missing something isn't.
    await s.db.insert('peers', {'id': id, 'name': name, 'public_key': base64.encode(publicKey), 'last_addr': address},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return Peer((await s.db.query('peers', where: 'id = ?', whereArgs: [id])).single);
  }

  // ── Client ───────────────────────────────────────────────────────────

  static Future<(int, Object?)> _post(InternetAddress address, int port, String path, Object body,
      {Duration timeout = const Duration(seconds: 60)}) async {
    if (!isLocal(address)) throw SyncFailure(SyncProblem.unreachable, 'not a local address');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.post(address.address, port, path);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final res = await req.close().timeout(timeout);
      final text = await _readJson(res).timeout(timeout).catchError((Object _) => null);
      return (res.statusCode, text);
    } on SocketException catch (e) {
      throw SyncFailure(SyncProblem.unreachable, e.message);
    } on TimeoutException {
      throw SyncFailure(SyncProblem.unreachable, 'timeout');
    } on HttpException catch (e) {
      throw SyncFailure(SyncProblem.unreachable, e.message);
    } finally {
      client.close(force: true);
    }
  }

  /// Pairs with the device at [address]. [confirm] shows the code and asks
  /// the user whether the other screen shows the same one. Returns the new
  /// peer and how many entries it has.
  Future<({Peer peer, int theirEntries})> pair(InternetAddress address, int port,
      {required Future<bool> Function(String code, String peerName) confirm}) async {
    final (status, start) = await _post(address, port, '/pair/start', {
      'v': protocol,
      'name': name,
      'pk': base64.encode(identity.publicKey),
    });
    if (status == HttpStatus.tooManyRequests) throw SyncFailure(SyncProblem.busy);
    if (status == HttpStatus.conflict) throw SyncFailure(SyncProblem.versionMismatch);
    if (status != HttpStatus.ok || start is! Map) throw SyncFailure(SyncProblem.declined, '$status');
    final peerKey = base64.decode(start['pk'] as String);
    final peerId = await SyncIdentity.idOf(peerKey);
    final peerName = (start['name'] as String? ?? '?').clip(40);
    final commit = base64.decode(start['commit'] as String);

    final na = SyncIdentity.randomBytes(32);
    final (status2, nonce) = await _post(address, port, '/pair/nonce', {'id': identity.id, 'nonce': base64.encode(na)});
    if (status2 != HttpStatus.ok || nonce is! Map) throw SyncFailure(SyncProblem.declined, '$status2');
    final nb = base64.decode(nonce['nonce'] as String);
    final expected = await SyncIdentity.commitment(peerKey, identity.publicKey, nb);
    if (base64.encode(expected) != base64.encode(commit)) throw SyncFailure(SyncProblem.codeMismatch);

    final code = await SyncIdentity.pairingCode(identity.publicKey, peerKey, na, nb);
    if (!await confirm(code, peerName)) {
      await _post(address, port, '/pair/cancel', {'id': identity.id}).catchError((Object _) => (0, null));
      throw SyncFailure(SyncProblem.codeMismatch);
    }
    final key = await identity.sharedKey(peerKey);
    final (status3, done) = await _post(address, port, '/pair/confirm',
        {'id': identity.id, 'sealed': await SyncIdentity.seal(key, 'pair:${identity.id}>$peerId', {'ok': true})},
        timeout: _pairTimeout + const Duration(seconds: 10));
    if (status3 != HttpStatus.ok || done is! Map) throw SyncFailure(SyncProblem.declined, '$status3');
    final answer = await SyncIdentity.open(key, 'pair:$peerId>${identity.id}', done['sealed']);
    if (answer is! Map || answer['ok'] != true) throw SyncFailure(SyncProblem.declined);
    final peer = await _savePeer(peerId, peerName, peerKey, address: address.address);
    return (peer: peer, theirEntries: start['entries'] as int? ?? 0);
  }

  /// Sends this device's changes to [peer] and takes theirs, in one round
  /// trip. Returns how many rows changed here. Safe to repeat: watermarks
  /// move only once the other side has the changes.
  Future<int> syncWith(Peer peer, InternetAddress address, int port) async {
    final s = await store();
    final key = await _keyFor(peer.id, peer.publicKey);
    final changes = await Merge.changesSince(s, peer.sentSeq);
    final challenge = base64.encode(SyncIdentity.randomBytes(16));
    final (status, body) = await _post(address, port, '/sync', {
      'from': identity.id,
      'sealed': await SyncIdentity.seal(key, 'sync:${identity.id}>${peer.id}', {
        'v': protocol,
        'schema': LocalStore.schemaVersion,
        'since': peer.receivedSeq,
        'changes': changes,
        'challenge': challenge,
      }),
    });
    if (status == HttpStatus.unauthorized) throw SyncFailure(SyncProblem.notPaired);
    if (status == HttpStatus.conflict) throw SyncFailure(SyncProblem.versionMismatch);
    if (status != HttpStatus.ok || body is! Map) throw SyncFailure(SyncProblem.failed, '$status');
    final reply = await SyncIdentity.open(key, 'sync:${peer.id}>${identity.id}', body['sealed']);
    if (reply is! Map || reply['challenge'] != challenge) throw SyncAuthError();
    await s.db.rawUpdate('UPDATE peers SET sent_seq = max(sent_seq, ?) WHERE id = ?', [changes['up_to'], peer.id]);
    final theirs = reply['changes'];
    final n = await Merge.apply(s, theirs);
    await s.db.rawUpdate('UPDATE peers SET received_seq = max(received_seq, ?), last_sync = ?, last_addr = ? WHERE id = ?',
        [(theirs as Map)['up_to'] as int? ?? 0, LocalStore.nowIso(), address.address, peer.id]);
    return n;
  }
}

class _PairSession {
  _PairSession(this.peerId, this.peerKey, this.peerName, this.nonce);
  final String peerId;
  final List<int> peerKey;
  final String peerName;
  final List<int> nonce;
  final started = DateTime.now();
  PairRequest? request;
  Future<bool>? decision;
}

extension on String {
  // A name from another device, cut to a length the UI can show.
  String clip(int max) => length <= max ? this : substring(0, max);
}
