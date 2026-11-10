import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../app_state.dart';
import '../models.dart';
import '../sessions.dart';
import '../terminal_themes.dart';

/// Opens a saved connection (counts it for "Frequently Used").
void openSession(BuildContext context, Connection c) {
  store.recordUse(c);
  openExisting(context, sessions.open(c));
}

void openExisting(BuildContext context, ActiveSession s) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => TerminalScreen(session: s)));

class TerminalScreen extends StatefulWidget {
  final ActiveSession session;
  const TerminalScreen({super.key, required this.session});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _focus = FocusNode();
  ActiveSession get session => widget.session;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _msg(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _copy() {
    final sel = session.controller.selection;
    if (sel == null) {
      _msg('Long-press text to select it first');
      return;
    }
    Clipboard.setData(ClipboardData(text: session.terminal.buffer.getText(sel)));
    session.controller.clearSelection();
    _msg('Copied');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) session.terminal.paste(text);
  }

  Future<void> _snippets() async {
    if (store.snippets.isEmpty) {
      _msg('No snippets yet — add them in Manage Connections → Snippets');
      return;
    }
    final cmd = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final s in store.snippets)
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(s.name.isEmpty ? s.command : s.name),
              subtitle: Text(s.command, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(c, s.command),
            ),
        ]),
      ),
    );
    if (cmd != null) session.runCommand(cmd);
  }

  void _reconnect() {
    final fresh = sessions.open(session.conn);
    sessions.close(session);
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => TerminalScreen(session: fresh)));
  }

  void _onMenu(String v) {
    switch (v) {
      case 'snippets':
        _snippets();
      case 'paste':
        _paste();
      case 'copy':
        _copy();
      case 'bigger':
        session.setFontSize(session.fontSize + 0.5);
      case 'smaller':
        session.setFontSize(session.fontSize - 0.5);
      case 'reconnect':
        _reconnect();
      case 'close':
        sessions.close(session);
        Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeByName(store.themeName);
    final darkBg = theme.background.computeLuminance() < 0.5;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: (darkBg ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: theme.background),
        child: Scaffold(
          backgroundColor: theme.background,
          body: SafeArea(
            child: Column(
              children: [
                if (session.finished)
                  MaterialBanner(
                    content: const Text('Session ended'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
                      TextButton(onPressed: _reconnect, child: const Text('RECONNECT')),
                    ],
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRect(
                          child: TerminalView(
                          session.terminal,
                          controller: session.controller,
                          focusNode: _focus,
                          autofocus: true,
                          backgroundOpacity: 1,
                          theme: theme,
                          textStyle: TerminalStyle(fontSize: session.fontSize),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Opacity(
                          opacity: 0.6,
                          child: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: theme.foreground),
                            onSelected: _onMenu,
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'snippets', child: Text('Snippets')),
                              const PopupMenuItem(value: 'paste', child: Text('Paste')),
                              const PopupMenuItem(value: 'copy', child: Text('Copy selection')),
                              const PopupMenuItem(value: 'bigger', child: Text('Larger font')),
                              const PopupMenuItem(value: 'smaller', child: Text('Smaller font')),
                              if (session.finished)
                                const PopupMenuItem(value: 'reconnect', child: Text('Reconnect')),
                              const PopupMenuItem(value: 'close', child: Text('Disconnect')),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _ExtraKeys(session: session, focus: _focus),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Two-row special key bar above the keyboard:
///   ESC  /  |  -  HOME  ↑  END  PGUP  FN
///   TAB CTRL ALT   ←   ↓   →  PGDN  ⌨
class _ExtraKeys extends StatefulWidget {
  final ActiveSession session;
  final FocusNode focus;
  const _ExtraKeys({required this.session, required this.focus});

  @override
  State<_ExtraKeys> createState() => _ExtraKeysState();
}

class _ExtraKeysState extends State<_ExtraKeys> {
  static const _barColor = Color(0xFF1F4552);
  static const _pressedColor = Color(0xFF2E6273);
  static const _activeColor = Color(0xFF3F8EA3);
  static const _textColor = Color(0xFFF1EBD5);

  Timer? _repeat;

  ActiveSession get s => widget.session;

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  void _toggleKeyboard() {
    final visible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (visible) {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } else {
      widget.focus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
  }

  Widget _cell({
    required int flex,
    String? label,
    IconData? icon,
    required VoidCallback onTap,
    bool active = false,
    bool repeat = false,
  }) {
    final content = SizedBox(
      height: 46,
      child: Center(
        child: icon != null
            ? Icon(icon, color: const Color(0xFFB8C4C8), size: 30)
            : Text(label!,
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.clip,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(
                    color: _textColor, fontSize: 19, height: 1.05, fontWeight: FontWeight.w500)),
      ),
    );

    Widget key = Material(
      color: active ? _activeColor : _barColor,
      child: InkWell(
        canRequestFocus: false,
        highlightColor: _pressedColor,
        splashColor: _pressedColor,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: content,
      ),
    );

    if (repeat) {
      key = GestureDetector(
        onLongPressStart: (_) {
          _repeat?.cancel();
          _repeat = Timer.periodic(const Duration(milliseconds: 70), (_) => onTap());
        },
        onLongPressEnd: (_) => _repeat?.cancel(),
        onLongPressCancel: () => _repeat?.cancel(),
        child: key,
      );
    }
    return Expanded(
      flex: flex,
      child: Padding(padding: const EdgeInsets.all(0.5), child: key),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Flex units: row 1 has 9 keys of 3 units; the first 3 keys of row 2
    // are 4 units wide so both rows line up from HOME/← onwards.
    return Container(
      color: const Color(0xFF173A45),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            _cell(flex: 3, label: 'ESC', onTap: () => s.sendKey(TerminalKey.escape)),
            _cell(flex: 3, label: '/', onTap: () => s.sendText('/')),
            _cell(flex: 3, label: '|', onTap: () => s.sendText('|')),
            _cell(flex: 3, label: '-', onTap: () => s.sendText('-')),
            _cell(flex: 3, label: 'HOME', onTap: () => s.sendKey(TerminalKey.home)),
            _cell(flex: 3, label: '↑', repeat: true, onTap: () => s.sendKey(TerminalKey.arrowUp)),
            _cell(flex: 3, label: 'END', onTap: () => s.sendKey(TerminalKey.end)),
            _cell(flex: 3, label: 'PGUP', onTap: () => s.sendKey(TerminalKey.pageUp)),
            _cell(flex: 3, label: 'FN', active: s.fn, onTap: s.toggleFn),
          ]),
          Row(children: [
            _cell(flex: 4, label: 'TAB', onTap: () => s.sendKey(TerminalKey.tab)),
            _cell(flex: 4, label: 'CTRL', active: s.ctrl, onTap: s.toggleCtrl),
            _cell(flex: 4, label: 'ALT', active: s.alt, onTap: s.toggleAlt),
            _cell(flex: 3, label: '←', repeat: true, onTap: () => s.sendKey(TerminalKey.arrowLeft)),
            _cell(flex: 3, label: '↓', repeat: true, onTap: () => s.sendKey(TerminalKey.arrowDown)),
            _cell(flex: 3, label: '→', repeat: true, onTap: () => s.sendKey(TerminalKey.arrowRight)),
            _cell(flex: 3, label: 'PGDN', onTap: () => s.sendKey(TerminalKey.pageDown)),
            _cell(flex: 3, icon: Icons.keyboard, onTap: _toggleKeyboard),
          ]),
        ],
      ),
    );
  }
}
