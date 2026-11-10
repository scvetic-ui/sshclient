import 'package:flutter/material.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Shows dialogs from non-UI code (password prompts, host key checks).
class Prompter {
  BuildContext? get _ctx => navigatorKey.currentContext;

  Future<String?> ask(String title, {bool secret = false, String initial = ''}) async {
    final ctx = _ctx;
    if (ctx == null) return null;
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          obscureText: secret,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<bool> confirm(String title, String message, {String ok = 'Continue'}) async {
    final ctx = _ctx;
    if (ctx == null) return false;
    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: SelectableText(message)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
        ],
      ),
    );
    return result ?? false;
  }
}
