import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xterm/xterm.dart';

import 'models.dart';
import 'prompter.dart';
import 'store.dart';

/// A thing that a terminal can talk to: SSH shell, Telnet socket or local PTY.
abstract class Backend {
  Future<void> start(Terminal terminal);
  void write(String data);
  void resize(int cols, int rows);
  Future<void> close();
  Future<void> get done;
}

// ---------------------------------------------------------------- SSH

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');

Future<bool> _verifyHostKey(
    Store store, Prompter ui, Connection c, String type, Uint8List fp) async {
  final key = '${c.host}:${c.port}';
  final value = '$type MD5:${_hex(fp)}';
  final known = store.knownHosts[key];
  if (known == value) return true;
  final bool ok;
  if (known == null) {
    ok = await ui.confirm(
      'Unknown host',
      'First connection to $key.\n\n$value\n\nTrust this host and save its key?',
      ok: 'Trust',
    );
  } else {
    ok = await ui.confirm(
      '⚠ Host key changed',
      'The host key for $key is DIFFERENT from the saved one.\n\n'
          'Saved: $known\nNew:   $value\n\n'
          'This can mean a man-in-the-middle attack. Only continue if you know '
          'the server was reinstalled.',
      ok: 'Replace key',
    );
  }
  if (ok) await store.trustHost(key, value);
  return ok;
}

/// Opens an authenticated SSH connection (used by shells and port forwards).
Future<SSHClient> connectSsh(Connection c, Store store, Prompter ui) async {
  var username = c.username;
  if (username.isEmpty) {
    username = await ui.ask('Username for ${c.host}') ?? '';
    if (username.isEmpty) throw Exception('No username');
  }

  List<SSHKeyPair>? identities;
  if (c.auth == AuthType.key && c.identityId != null) {
    final pem = await store.privateKey(c.identityId!);
    if (pem == null) throw Exception('Private key not found');
    var pass = await store.passphrase(c.identityId!);
    if ((pass == null || pass.isEmpty) && SSHKeyPair.isEncryptedPem(pem)) {
      pass = await ui.ask('Key passphrase', secret: true);
    }
    identities = SSHKeyPair.fromPem(pem, pass);
  }

  final saved = await store.password(c.id);
  var usedSaved = false;

  final socket = await SSHSocket.connect(c.host, c.port, timeout: const Duration(seconds: 15));
  final client = SSHClient(
    socket,
    username: username,
    identities: identities,
    onVerifyHostKey: (type, fp) => _verifyHostKey(store, ui, c, type, fp),
    onPasswordRequest: () async {
      if (saved != null && saved.isNotEmpty && !usedSaved) {
        usedSaved = true;
        return saved;
      }
      return ui.ask('Password for $username@${c.host}', secret: true);
    },
  );
  await client.authenticated;
  return client;
}

class SshBackend implements Backend {
  final Connection conn;
  final Store store;
  final Prompter ui;
  SSHClient? _client;
  SSHSession? _session;
  final _done = Completer<void>();

  SshBackend(this.conn, this.store, this.ui);

  @override
  Future<void> get done => _done.future;

  void _finish() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> start(Terminal t) async {
    t.write('Connecting to ${conn.host}:${conn.port}...\r\n');
    _client = await connectSsh(conn, store, ui);
    _session = await _client!.shell(
      pty: SSHPtyConfig(width: t.viewWidth, height: t.viewHeight, type: 'xterm-256color'),
    );
    _session!.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(t.write);
    _session!.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(t.write);
    _session!.done.catchError((_) {}).whenComplete(_finish);
    _client!.done.catchError((_) {}).whenComplete(_finish);
  }

  @override
  void write(String data) => _session?.write(Uint8List.fromList(utf8.encode(data)));

  @override
  void resize(int cols, int rows) => _session?.resizeTerminal(cols, rows);

  @override
  Future<void> close() async {
    _session?.close();
    _client?.close();
    _finish();
  }
}

// ---------------------------------------------------------------- Telnet

class _TerminalSink implements Sink<String> {
  final Terminal t;
  _TerminalSink(this.t);
  @override
  void add(String data) => t.write(data);
  @override
  void close() {}
}

class TelnetBackend implements Backend {
  static const iac = 255, dont = 254, doo = 253, wont = 252, will = 251, sb = 250, se = 240;
  static const optEcho = 1, optSga = 3, optTtype = 24, optNaws = 31;

  final Connection conn;
  Socket? _socket;
  late ByteConversionSink _utf;
  final _done = Completer<void>();
  int _cols = 80, _rows = 24;
  bool _naws = false;

  int _state = 0;
  int _cmd = 0;
  final _sbBuf = <int>[];

  TelnetBackend(this.conn);

  @override
  Future<void> get done => _done.future;

  void _finish() {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> start(Terminal t) async {
    _cols = t.viewWidth;
    _rows = t.viewHeight;
    _utf = const Utf8Decoder(allowMalformed: true).startChunkedConversion(_TerminalSink(t));
    t.write('Connecting to ${conn.host}:${conn.port}...\r\n');
    _socket = await Socket.connect(conn.host, conn.port, timeout: const Duration(seconds: 15));
    _socket!.listen(_onData, onDone: _finish, onError: (_) => _finish(), cancelOnError: true);
  }

  void _send(List<int> bytes) => _socket?.add(bytes);

  void _onData(Uint8List data) {
    final out = <int>[];
    for (final b in data) {
      switch (_state) {
        case 0:
          if (b == iac) {
            _state = 1;
          } else {
            out.add(b);
          }
        case 1:
          if (b == iac) {
            out.add(255);
            _state = 0;
          } else if (b >= will && b <= dont) {
            _cmd = b;
            _state = 2;
          } else if (b == sb) {
            _sbBuf.clear();
            _state = 3;
          } else {
            _state = 0;
          }
        case 2:
          _negotiate(_cmd, b);
          _state = 0;
        case 3:
          if (b == iac) {
            _state = 4;
          } else {
            _sbBuf.add(b);
          }
        case 4:
          if (b == se) {
            _subnegotiation();
            _state = 0;
          } else {
            _sbBuf.add(b);
            _state = 3;
          }
      }
    }
    if (out.isNotEmpty) _utf.add(out);
  }

  void _negotiate(int cmd, int opt) {
    if (cmd == doo) {
      if (opt == optNaws) {
        _send([iac, will, optNaws]);
        _naws = true;
        _sendSize();
      } else if (opt == optTtype) {
        _send([iac, will, optTtype]);
      } else {
        _send([iac, wont, opt]);
      }
    } else if (cmd == will) {
      _send([iac, (opt == optEcho || opt == optSga) ? doo : dont, opt]);
    } else if (cmd == dont && opt == optNaws) {
      _naws = false;
    }
  }

  void _subnegotiation() {
    // TTYPE SEND -> reply with our terminal type
    if (_sbBuf.length >= 2 && _sbBuf[0] == optTtype && _sbBuf[1] == 1) {
      _send([iac, sb, optTtype, 0, ...ascii.encode('XTERM-256COLOR'), iac, se]);
    }
  }

  void _sendSize() {
    if (!_naws) return;
    _send([iac, sb, optNaws, _cols >> 8, _cols & 255, _rows >> 8, _rows & 255, iac, se]);
  }

  @override
  void write(String data) {
    final bytes = <int>[];
    for (final b in utf8.encode(data.replaceAll('\r', '\r\n'))) {
      bytes.add(b);
      if (b == iac) bytes.add(iac);
    }
    _send(bytes);
  }

  @override
  void resize(int cols, int rows) {
    _cols = cols;
    _rows = rows;
    _sendSize();
  }

  @override
  Future<void> close() async {
    _socket?.destroy();
    _finish();
  }
}

// ---------------------------------------------------------------- Local shell

class LocalBackend implements Backend {
  Pty? _pty;
  final _done = Completer<void>();

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> start(Terminal t) async {
    final home = (await getApplicationDocumentsDirectory()).path;
    final shell = File('/system/bin/sh').existsSync() ? '/system/bin/sh' : '/bin/sh';
    _pty = Pty.start(
      shell,
      columns: t.viewWidth,
      rows: t.viewHeight,
      workingDirectory: home,
      environment: {
        ...Platform.environment,
        'TERM': 'xterm-256color',
        'HOME': home,
      },
    );
    _pty!.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(t.write);
    _pty!.exitCode.then((_) {
      if (!_done.isCompleted) _done.complete();
    });
  }

  @override
  void write(String data) => _pty?.write(Uint8List.fromList(utf8.encode(data)));

  @override
  void resize(int cols, int rows) => _pty?.resize(rows, cols);

  @override
  Future<void> close() async {
    _pty?.kill();
    if (!_done.isCompleted) _done.complete();
  }
}
