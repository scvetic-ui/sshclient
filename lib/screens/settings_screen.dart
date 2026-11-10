import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../app_state.dart';
import '../terminal_themes.dart';
import 'tabs.dart' show snack;

Future<void> _export(BuildContext context, bool secrets) async {
  if (secrets) {
    final ok = await prompter.confirm(
      'Include passwords and keys?',
      'The backup will contain your saved passwords and private keys in plain text. '
          'Paste it only somewhere private (e.g. a password manager) and clear the '
          'keyboard clipboard history afterwards.',
      ok: 'Copy',
    );
    if (!ok) return;
  }
  final text = await store.exportJson(secrets: secrets);
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) snack(context, 'Backup copied — paste it into a safe place (Notes, email to yourself…)');
}

Future<void> _import(BuildContext context) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text?.trim() ?? '';
  if (text.isEmpty) {
    snack(context, 'Clipboard is empty — copy the backup text first');
    return;
  }
  try {
    final r = await store.importJson(text);
    if (context.mounted) snack(context, 'Imported: $r');
  } catch (e) {
    if (context.mounted) snack(context, 'Import failed: $e');
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        title: const Text('Settings'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          children: [
            const ListTile(title: Text('Font size', style: TextStyle(fontWeight: FontWeight.bold))),
            Row(children: [
              Expanded(
                child: Slider(
                  value: store.fontSize,
                  min: 6,
                  max: 24,
                  divisions: 36,
                  label: store.fontSize.toStringAsFixed(1),
                  onChanged: (v) {
                    store.fontSize = v;
                    store.saveSettings();
                  },
                ),
              ),
              SizedBox(width: 48, child: Text(store.fontSize.toStringAsFixed(1))),
            ]),
            const Divider(),
            const ListTile(
                title: Text('Colour scheme', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final e in terminalThemes.entries)
              ListTile(
                title: Text(e.key),
                leading: _Preview(e.value),
                trailing: store.themeName == e.key ? const Icon(Icons.check, color: kBrand) : null,
                onTap: () {
                  store.themeName = e.key;
                  store.saveSettings();
                },
              ),
            const Divider(),
            const ListTile(title: Text('Backup', style: TextStyle(fontWeight: FontWeight.bold))),
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Export (no passwords)'),
              subtitle: const Text('Connections, snippets, forwards → clipboard'),
              onTap: () => _export(context, false),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Export with passwords and keys'),
              subtitle: const Text('Plain text — keep it private'),
              onTap: () => _export(context, true),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Import from clipboard'),
              subtitle: const Text('Copy the backup text first, then tap here'),
              onTap: () => _import(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final TerminalTheme t;
  const _Preview(this.t);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final c in [t.foreground, t.red, t.green, t.blue, t.yellow])
            Container(width: 7, height: 18, color: c),
        ],
      ),
    );
  }
}
