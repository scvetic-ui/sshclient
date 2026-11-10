import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../keygen.dart';
import '../models.dart';
import '../store.dart';
import 'editors.dart';
import 'terminal_screen.dart';

void snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

Widget _header(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text,
          style: TextStyle(
              color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
    );

Widget _empty(String text) => Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
    );

Future<bool> _confirmDelete(BuildContext context, String what) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Delete $what?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
      ],
    ),
  );
  return r ?? false;
}

IconData _typeIcon(ConnType t) => switch (t) {
      ConnType.ssh => Icons.terminal,
      ConnType.telnet => Icons.lan_outlined,
      ConnType.local => Icons.phone_android,
    };

// ------------------------------------------------------------ Connections

class ConnectionsTab extends StatelessWidget {
  const ConnectionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        _header(context, 'Connections'),
        if (store.connections.isEmpty)
          _empty('No connections yet.\nTap + to add a server, or ⚡ for quick connect.'),
        for (final c in store.connections)
          ListTile(
            leading: Icon(_typeIcon(c.type)),
            title: Text(c.label),
            subtitle: Text(c.name.isEmpty ? connTypeLabel(c.type) : '${connTypeLabel(c.type)} · ${c.address}'),
            onTap: () => openSession(context, c),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ConnectionEditScreen(existing: c)));
                } else if (v == 'delete' && await _confirmDelete(context, c.label)) {
                  await store.deleteConnection(c);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------ Snippets

class SnippetsTab extends StatelessWidget {
  const SnippetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (store.snippets.isEmpty) {
      return Center(
          child: _empty('No snippets yet.\nSave commands you use often and run them '
              'from the terminal toolbar, or automatically on connect.'));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final s in store.snippets)
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(s.name.isEmpty ? s.command : s.name),
            subtitle: Text(s.command,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace')),
            onTap: () => editSnippet(context, s),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await _confirmDelete(context, 'snippet')) await store.deleteSnippet(s);
              },
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------ Identities

Future<void> showPublicKey(BuildContext context, Identity i) => showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(i.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Public key — add this line to ~/.ssh/authorized_keys on the server:'),
              const SizedBox(height: 12),
              SelectableText(i.publicKey,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
          FilledButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: i.publicKey));
              Navigator.pop(c);
              snack(context, 'Public key copied');
            },
          ),
        ],
      ),
    );

Future<void> addIdentity(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('Generate new key (Ed25519)'),
          onTap: () => Navigator.pop(c, 'gen'),
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Import private key'),
          subtitle: const Text('OpenSSH or PEM (RSA, ECDSA, Ed25519)'),
          onTap: () => Navigator.pop(c, 'import'),
        ),
      ]),
    ),
  );
  if (!context.mounted) return;
  if (choice == 'import') {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const IdentityImportScreen()));
  } else if (choice == 'gen') {
    final name = await prompter.ask('Key name', initial: 'lemon-phone');
    if (name == null || name.trim().isEmpty) return;
    final g = generateEd25519(name.trim());
    final id = Identity(id: newId(), name: name.trim(), keyType: 'ssh-ed25519', publicKey: g.publicLine);
    await store.saveIdentity(id, privatePem: g.privatePem);
    if (context.mounted) await showPublicKey(context, id);
  }
}

class IdentitiesTab extends StatelessWidget {
  const IdentitiesTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (store.identities.isEmpty) {
      return Center(
          child: _empty('No SSH keys yet.\nTap + to generate a key or import an existing one.'));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final i in store.identities)
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(i.name),
            subtitle: Text(i.keyType),
            onTap: () => showPublicKey(context, i),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await _confirmDelete(context, 'key "${i.name}"')) await store.deleteIdentity(i);
              },
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------ Port forwards

class ForwardsTab extends StatelessWidget {
  const ForwardsTab({super.key});

  @override
  Widget build(BuildContext context) {
    if (store.portForwards.isEmpty) {
      return Center(
          child: _empty('No port forwards yet.\n'
              'Local: open a port on the phone that leads to a service behind the server.\n'
              'Remote: open a port on the server that leads back to the phone.'));
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final f in store.portForwards)
          ListTile(
            leading: Icon(f.type == ForwardType.local ? Icons.call_received : Icons.call_made),
            title: Text(f.name.isEmpty ? f.summary : f.name),
            subtitle: Text('${f.summary}\nvia ${store.connection(f.connectionId)?.label ?? '?'}'),
            isThreeLine: true,
            onLongPress: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => ForwardEditScreen(existing: f))),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (forwards.isStarting(f.id))
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                Switch(
                  value: forwards.isRunning(f.id),
                  onChanged: (on) async {
                    try {
                      if (on) {
                        await forwards.start(f);
                      } else {
                        await forwards.stop(f.id);
                      }
                    } catch (e) {
                      if (context.mounted) snack(context, 'Failed: $e');
                    }
                  },
                ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ForwardEditScreen(existing: f)));
                  } else if (v == 'delete' && await _confirmDelete(context, 'port forward')) {
                    await forwards.stop(f.id);
                    await store.deleteForward(f);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ]),
          ),
      ],
    );
  }
}
