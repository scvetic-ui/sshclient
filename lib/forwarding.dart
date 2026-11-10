import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import 'app_state.dart';
import 'backends.dart';
import 'models.dart';

class _Running {
  final SSHClient client;
  ServerSocket? server;
  _Running(this.client);
}

/// Starts/stops SSH port forwards (-L local and -R remote).
class ForwardManager extends ChangeNotifier {
  final Map<String, _Running> _running = {};
  final Set<String> _starting = {};

  bool isRunning(String id) => _running.containsKey(id);
  bool isStarting(String id) => _starting.contains(id);

  Future<void> start(PortForward f) async {
    if (isRunning(f.id) || isStarting(f.id)) return;
    final conn = store.connection(f.connectionId);
    if (conn == null) throw Exception('Connection not found');
    _starting.add(f.id);
    notifyListeners();
    SSHClient? client;
    try {
      client = await connectSsh(conn, store, prompter);
      final r = _Running(client);
      if (f.type == ForwardType.local) {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, f.bindPort);
        r.server = server;
        final c = client;
        server.listen((sock) async {
          try {
            final ch = await c.forwardLocal(f.targetHost, f.targetPort);
            _pipe(sock, ch);
          } catch (_) {
            sock.destroy();
          }
        });
      } else {
        final remote = await client.forwardRemote(port: f.bindPort);
        if (remote == null) throw Exception('Server refused remote forward on port ${f.bindPort}');
        remote.connections.listen((ch) async {
          try {
            final sock = await Socket.connect(f.targetHost, f.targetPort,
                timeout: const Duration(seconds: 10));
            _pipe(sock, ch);
          } catch (_) {
            ch.destroy();
          }
        });
      }
      _running[f.id] = r;
      client.done.catchError((_) {}).whenComplete(() {
        final removed = _running.remove(f.id);
        removed?.server?.close();
        notifyListeners();
      });
    } catch (e) {
      client?.close();
      rethrow;
    } finally {
      _starting.remove(f.id);
      notifyListeners();
    }
  }

  void _pipe(Socket sock, SSHForwardChannel ch) {
    sock.listen(
      (data) => ch.sink.add(data),
      onDone: () => ch.sink.close(),
      onError: (_) => ch.destroy(),
      cancelOnError: true,
    );
    ch.stream.listen(
      (data) => sock.add(data),
      onDone: () => sock.destroy(),
      onError: (_) => sock.destroy(),
      cancelOnError: true,
    );
  }

  Future<void> stop(String id) async {
    final r = _running.remove(id);
    notifyListeners();
    await r?.server?.close();
    r?.client.close();
  }
}
