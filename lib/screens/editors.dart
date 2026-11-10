import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../keygen.dart';
import '../models.dart';
import '../store.dart';

const _gap = SizedBox(height: 16);

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

// ------------------------------------------------------------ Connection

class ConnectionEditScreen extends StatefulWidget {
  final Connection? existing;
  const ConnectionEditScreen({super.key, this.existing});

  @override
  State<ConnectionEditScreen> createState() => _ConnectionEditScreenState();
}

class _ConnectionEditScreenState extends State<ConnectionEditScreen> {
  late final Connection c = widget.existing != null
      ? Connection.fromJson(widget.existing!.toJson())
      : Connection(id: newId());
  late final _name = TextEditingController(text: c.name);
  late final _host = TextEditingController(text: c.host);
  late final _port = TextEditingController(text: '${c.port}');
  late final _user = TextEditingController(text: c.username);
  final _pass = TextEditingController();
  bool _clearPass = false;

  @override
  void dispose() {
    for (final t in [_name, _host, _port, _user, _pass]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    c.name = _name.text.trim();
    c.host = _host.text.trim();
    c.port = int.tryParse(_port.text.trim()) ?? defaultPort(c.type);
    c.username = _user.text.trim();
    if (c.type != ConnType.local && c.host.isEmpty) {
      _snack(context, 'Host is required');
      return;
    }
    if (c.type == ConnType.ssh && c.auth == AuthType.key && c.identityId == null) {
      _snack(context, 'Choose a key (identity)');
      return;
    }
    if (_clearPass) await store.clearPassword(c.id);
    await store.saveConnection(c, password: _pass.text.isEmpty ? null : _pass.text);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isSsh = c.type == ConnType.ssh;
    final isRemote = c.type != ConnType.local;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New connection' : 'Edit connection'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ConnType>(
            segments: const [
              ButtonSegment(value: ConnType.ssh, label: Text('SSH')),
              ButtonSegment(value: ConnType.telnet, label: Text('Telnet')),
              ButtonSegment(value: ConnType.local, label: Text('Local')),
            ],
            selected: {c.type},
            onSelectionChanged: (v) => setState(() {
              final old = c.type;
              c.type = v.first;
              if (_port.text.trim() == '${defaultPort(old)}') {
                _port.text = '${defaultPort(c.type)}';
              }
            }),
          ),
          _gap,
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nickname (optional)'),
          ),
          if (isRemote) ...[
            _gap,
            TextField(
              controller: _host,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Host / IP address'),
            ),
            _gap,
            TextField(
              controller: _port,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port'),
            ),
          ],
          if (isSsh) ...[
            _gap,
            TextField(
              controller: _user,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            _gap,
            SegmentedButton<AuthType>(
              segments: const [
                ButtonSegment(value: AuthType.password, label: Text('Password')),
                ButtonSegment(value: AuthType.key, label: Text('SSH key')),
              ],
              selected: {c.auth},
              onSelectionChanged: (v) => setState(() => c.auth = v.first),
            ),
            _gap,
            if (c.auth == AuthType.password) ...[
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password (optional)',
                  helperText: widget.existing == null
                      ? 'Leave empty to be asked on every connect'
                      : 'Leave empty to keep the saved one',
                ),
              ),
              if (widget.existing != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _clearPass,
                  onChanged: (v) => setState(() => _clearPass = v ?? false),
                  title: const Text('Forget saved password'),
                ),
            ] else if (store.identities.isEmpty)
              const Text('No keys yet — add one in the Identities tab.',
                  style: TextStyle(color: Colors.deepOrange))
            else
              DropdownButtonFormField<String>(
                initialValue: c.identityId,
                decoration: const InputDecoration(labelText: 'Key'),
                items: [
                  for (final i in store.identities)
                    DropdownMenuItem(value: i.id, child: Text(i.name)),
                ],
                onChanged: (v) => setState(() => c.identityId = v),
              ),
          ],
          _gap,
          DropdownButtonFormField<String?>(
            initialValue: c.startupSnippetId,
            decoration: const InputDecoration(labelText: 'Run snippet after connect'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('None')),
              for (final s in store.snippets)
                DropdownMenuItem<String?>(value: s.id, child: Text(s.name.isEmpty ? s.command : s.name)),
            ],
            onChanged: (v) => setState(() => c.startupSnippetId = v),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Snippet

Future<void> editSnippet(BuildContext context, [Snippet? existing]) async {
  final name = TextEditingController(text: existing?.name ?? '');
  final cmd = TextEditingController(text: existing?.command ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(existing == null ? 'New snippet' : 'Edit snippet'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 12),
        TextField(
          controller: cmd,
          autocorrect: false,
          enableSuggestions: false,
          minLines: 2,
          maxLines: 6,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: const InputDecoration(labelText: 'Command', hintText: 'df -h; uptime'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok == true && cmd.text.trim().isNotEmpty) {
    final s = existing ?? Snippet(id: newId());
    s.name = name.text.trim();
    s.command = cmd.text.trim();
    await store.saveSnippet(s);
  }
  name.dispose();
  cmd.dispose();
}

// ------------------------------------------------------------ Identity import

class IdentityImportScreen extends StatefulWidget {
  const IdentityImportScreen({super.key});

  @override
  State<IdentityImportScreen> createState() => _IdentityImportScreenState();
}

class _IdentityImportScreenState extends State<IdentityImportScreen> {
  final _name = TextEditingController();
  final _pem = TextEditingController();
  final _pass = TextEditingController();
  bool _encrypted = false;

  @override
  void initState() {
    super.initState();
    _pem.addListener(() {
      final e = isEncryptedKey(_pem.text);
      if (e != _encrypted) setState(() => _encrypted = e);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _pem.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) _pem.text = data!.text!.trim();
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? 'Imported key' : _name.text.trim();
    final pem = '${_pem.text.trim()}\n';
    final pass = _pass.text.isEmpty ? null : _pass.text;
    try {
      final info = inspectPrivateKey(pem, pass, name);
      final id = Identity(id: newId(), name: name, keyType: info.type, publicKey: info.publicLine);
      await store.saveIdentity(id, privatePem: pem, passphrase: pass);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack(context, 'Invalid key or wrong passphrase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import key'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          _gap,
          TextField(
            controller: _pem,
            minLines: 6,
            maxLines: 12,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            decoration: const InputDecoration(
              labelText: 'Private key',
              hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...',
              border: OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.paste),
              label: const Text('Paste from clipboard'),
            ),
          ),
          if (_encrypted)
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Port forward

class ForwardEditScreen extends StatefulWidget {
  final PortForward? existing;
  const ForwardEditScreen({super.key, this.existing});

  @override
  State<ForwardEditScreen> createState() => _ForwardEditScreenState();
}

class _ForwardEditScreenState extends State<ForwardEditScreen> {
  late final PortForward f = widget.existing != null
      ? PortForward.fromJson(widget.existing!.toJson())
      : PortForward(
          id: newId(),
          connectionId: store.connections.firstWhere((c) => c.type == ConnType.ssh).id,
        );
  late final _name = TextEditingController(text: f.name);
  late final _bind = TextEditingController(text: '${f.bindPort}');
  late final _host = TextEditingController(text: f.targetHost);
  late final _port = TextEditingController(text: '${f.targetPort}');

  @override
  void dispose() {
    for (final t in [_name, _bind, _host, _port]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final bind = int.tryParse(_bind.text.trim());
    final port = int.tryParse(_port.text.trim());
    if (bind == null || port == null || _host.text.trim().isEmpty) {
      _snack(context, 'Fill in both ports and the target host');
      return;
    }
    f.name = _name.text.trim();
    f.bindPort = bind;
    f.targetPort = port;
    f.targetHost = _host.text.trim();
    await store.saveForward(f);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final local = f.type == ForwardType.local;
    final sshConns = store.connections.where((c) => c.type == ConnType.ssh).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New port forward' : 'Edit port forward'),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name (optional)')),
          _gap,
          DropdownButtonFormField<String>(
            initialValue: sshConns.any((c) => c.id == f.connectionId) ? f.connectionId : null,
            decoration: const InputDecoration(labelText: 'Through SSH connection'),
            items: [
              for (final c in sshConns) DropdownMenuItem(value: c.id, child: Text(c.label)),
            ],
            onChanged: (v) => setState(() => f.connectionId = v ?? f.connectionId),
          ),
          _gap,
          SegmentedButton<ForwardType>(
            segments: const [
              ButtonSegment(value: ForwardType.local, label: Text('Local (-L)')),
              ButtonSegment(value: ForwardType.remote, label: Text('Remote (-R)')),
            ],
            selected: {f.type},
            onSelectionChanged: (v) => setState(() => f.type = v.first),
          ),
          const SizedBox(height: 8),
          Text(
            local
                ? 'Opens a port on this phone (127.0.0.1). Connections go through the '
                    'server to the target host — e.g. reach a database that only listens on the server.'
                : 'Opens a port on the server. Connections come back through SSH to the '
                    'target host as seen from this phone.',
            style: const TextStyle(color: Colors.black54),
          ),
          _gap,
          TextField(
            controller: _bind,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: local ? 'Port on phone' : 'Port on server'),
          ),
          _gap,
          TextField(
            controller: _host,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Target host'),
          ),
          _gap,
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Target port'),
          ),
        ],
      ),
    );
  }
}
