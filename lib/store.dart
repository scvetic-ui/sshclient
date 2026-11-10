import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Saves connections, keys, snippets and forwards.
/// Non-secret data goes to a JSON file; passwords and private keys go to
/// Android encrypted secure storage.
class Store extends ChangeNotifier {
  static const _secure = FlutterSecureStorage();
  File? _file;

  final connections = <Connection>[];
  final identities = <Identity>[];
  final snippets = <Snippet>[];
  final portForwards = <PortForward>[];
  final knownHosts = <String, String>{};

  // settings
  double fontSize = 14;
  String themeName = 'Solarized Dark';

  Future<void> load() async {
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/data.json');
    if (!await _file!.exists()) return;
    try {
      final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
      List<Map<String, dynamic>> list(String k) =>
          ((j[k] as List?) ?? const []).cast<Map<String, dynamic>>();
      connections.addAll(list('connections').map(Connection.fromJson));
      identities.addAll(list('identities').map(Identity.fromJson));
      snippets.addAll(list('snippets').map(Snippet.fromJson));
      portForwards.addAll(list('portForwards').map(PortForward.fromJson));
      final st = ((j['settings'] as Map?) ?? const {}).cast<String, dynamic>();
      fontSize = (st['fontSize'] as num?)?.toDouble() ?? fontSize;
      themeName = st['theme'] as String? ?? themeName;
      knownHosts.addAll(((j['knownHosts'] as Map?) ?? const {}).cast<String, String>());
    } catch (e) {
      debugPrint('Could not load data: $e');
    }
  }

  Future<void> _save() async {
    final data = {
      'connections': connections.map((e) => e.toJson()).toList(),
      'identities': identities.map((e) => e.toJson()).toList(),
      'snippets': snippets.map((e) => e.toJson()).toList(),
      'portForwards': portForwards.map((e) => e.toJson()).toList(),
      'knownHosts': knownHosts,
      'settings': {'fontSize': fontSize, 'theme': themeName},
    };
    await _file?.writeAsString(jsonEncode(data));
    notifyListeners();
  }

  // ---- lookups ----
  T? _find<T>(List<T> list, String? id, String Function(T) key) {
    if (id == null) return null;
    for (final e in list) {
      if (key(e) == id) return e;
    }
    return null;
  }

  Connection? connection(String? id) => _find(connections, id, (e) => e.id);
  Identity? identity(String? id) => _find(identities, id, (e) => e.id);
  Snippet? snippet(String? id) => _find(snippets, id, (e) => e.id);

  void _upsert<T>(List<T> list, T item, String Function(T) key) {
    final i = list.indexWhere((e) => key(e) == key(item));
    if (i < 0) {
      list.add(item);
    } else {
      list[i] = item;
    }
  }

  // ---- connections ----
  Future<void> saveConnection(Connection c, {String? password}) async {
    _upsert(connections, c, (e) => e.id);
    if (password != null) await _secure.write(key: 'pw_${c.id}', value: password);
    await _save();
  }

  Future<String?> password(String connectionId) => _secure.read(key: 'pw_$connectionId');

  Future<void> clearPassword(String connectionId) => _secure.delete(key: 'pw_$connectionId');

  Future<void> deleteConnection(Connection c) async {
    connections.removeWhere((e) => e.id == c.id);
    portForwards.removeWhere((e) => e.connectionId == c.id);
    await _secure.delete(key: 'pw_${c.id}');
    await _save();
  }

  // ---- identities ----
  Future<void> saveIdentity(Identity i, {String? privatePem, String? passphrase}) async {
    _upsert(identities, i, (e) => e.id);
    if (privatePem != null) await _secure.write(key: 'key_${i.id}', value: privatePem);
    if (passphrase != null) await _secure.write(key: 'pass_${i.id}', value: passphrase);
    await _save();
  }

  Future<String?> privateKey(String identityId) => _secure.read(key: 'key_$identityId');
  Future<String?> passphrase(String identityId) => _secure.read(key: 'pass_$identityId');

  Future<void> deleteIdentity(Identity i) async {
    identities.removeWhere((e) => e.id == i.id);
    for (final c in connections) {
      if (c.identityId == i.id) {
        c.identityId = null;
        c.auth = AuthType.password;
      }
    }
    await _secure.delete(key: 'key_${i.id}');
    await _secure.delete(key: 'pass_${i.id}');
    await _save();
  }

  // ---- snippets ----
  Future<void> saveSnippet(Snippet s) async {
    _upsert(snippets, s, (e) => e.id);
    await _save();
  }

  Future<void> deleteSnippet(Snippet s) async {
    snippets.removeWhere((e) => e.id == s.id);
    for (final c in connections) {
      if (c.startupSnippetId == s.id) c.startupSnippetId = null;
    }
    await _save();
  }

  // ---- port forwards ----
  Future<void> saveForward(PortForward f) async {
    _upsert(portForwards, f, (e) => e.id);
    await _save();
  }

  Future<void> deleteForward(PortForward f) async {
    portForwards.removeWhere((e) => e.id == f.id);
    await _save();
  }

  // ---- settings / usage ----
  Future<void> saveSettings() => _save();

  Future<void> recordUse(Connection c) async {
    final saved = connection(c.id);
    if (saved == null) return;
    saved.useCount++;
    await _save();
  }

  // ---- known hosts ----
  Future<void> trustHost(String hostKey, String fingerprint) async {
    knownHosts[hostKey] = fingerprint;
    await _save();
  }
}
