import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import 'app_state.dart';
import 'backends.dart';
import 'models.dart';
import 'store.dart';

/// One open terminal. Stays alive when you leave the terminal screen,
/// so you can switch between several sessions (like JuiceSSH).
class ActiveSession extends ChangeNotifier {
  final String id = newId();
  final Connection conn;
  final Backend backend;
  final Terminal terminal = Terminal(maxLines: 10000);
  final TerminalController controller = TerminalController();

  bool connected = false;
  bool finished = false;
  bool ctrl = false;
  bool alt = false;
  bool fn = false;
  double fontSize = store.fontSize;

  ActiveSession(this.conn, this.backend) {
    terminal.onOutput = handleInput;
    terminal.onResize = (w, h, pw, ph) => backend.resize(w, h);
  }

  String get title => conn.label;

  void toggleCtrl() {
    ctrl = !ctrl;
    notifyListeners();
  }

  void toggleFn() {
    fn = !fn;
    notifyListeners();
  }

  void toggleAlt() {
    alt = !alt;
    notifyListeners();
  }

  /// All keyboard input goes through here so the on-screen CTRL/ALT work.
  void handleInput(String data) {
    // FN + 1..0 - = gives F1..F12 (like JuiceSSH)
    if (fn && data.length == 1) {
      fn = false;
      notifyListeners();
      final i = '1234567890-='.indexOf(data);
      if (i >= 0) {
        terminal.keyInput(TerminalKey.values.byName('f${i + 1}'));
        return;
      }
    }
    if (ctrl && data.length == 1) {
      final c = data.toUpperCase().codeUnitAt(0);
      if (c >= 64 && c <= 95) {
        data = String.fromCharCode(c - 64);
      } else if (data == ' ') {
        data = '\x00';
      }
      ctrl = false;
      notifyListeners();
    }
    if (alt) {
      data = '\x1b$data';
      alt = false;
      notifyListeners();
    }
    backend.write(data);
  }

  void sendKey(TerminalKey key) {
    final c = ctrl, a = alt;
    ctrl = false;
    alt = false;
    fn = false;
    notifyListeners();
    terminal.keyInput(key, ctrl: c, alt: a);
  }

  void sendText(String text) => handleInput(text);

  void runCommand(String command) => backend.write('$command\r');

  void setFontSize(double size) {
    fontSize = size.clamp(6, 32).toDouble();
    notifyListeners();
  }

  void markChanged() => notifyListeners();
}

class SessionManager extends ChangeNotifier {
  final List<ActiveSession> sessions = [];

  void _syncBackground() {
    final live = sessions.where((s) => !s.finished).toList();
    final text = live.isEmpty ? '' : live.map((s) => s.title).join(', ');
    background.sync(live.length, text);
  }

  ActiveSession open(Connection c) {
    final Backend backend = switch (c.type) {
      ConnType.ssh => SshBackend(c, store, prompter),
      ConnType.telnet => TelnetBackend(c),
      ConnType.local => LocalBackend(),
    };
    final s = ActiveSession(c, backend);
    sessions.add(s);
    notifyListeners();
    _syncBackground();
    _run(s);
    return s;
  }

  Future<void> _run(ActiveSession s) async {
    try {
      await s.backend.start(s.terminal);
      s.connected = true;
      _changed(s);
      final snippet = store.snippet(s.conn.startupSnippetId);
      if (snippet != null) s.runCommand(snippet.command);
      await s.backend.done;
    } catch (e) {
      s.terminal.write('\r\n\x1b[31mError: $e\x1b[0m\r\n');
    }
    s.connected = false;
    s.finished = true;
    s.terminal.write('\r\n\x1b[33m[Disconnected]\x1b[0m\r\n');
    _changed(s);
  }

  void _changed(ActiveSession s) {
    s.markChanged();
    notifyListeners();
    _syncBackground();
  }

  Future<void> close(ActiveSession s) async {
    sessions.remove(s);
    notifyListeners();
    _syncBackground();
    await s.backend.close();
  }
}
