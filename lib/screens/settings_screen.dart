import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../app_state.dart';
import '../terminal_themes.dart';

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
