import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../sessions.dart';

/// Opens the file browser for an SSH session (SFTP over the same connection).
void openFiles(BuildContext context, ActiveSession session) {
  final client = session.sshClient;
  if (client == null) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File transfer needs a connected SSH session')));
    return;
  }
  Navigator.push(
      context, MaterialPageRoute(builder: (_) => FilesScreen(session: session, client: client)));
}

String _fmtSize(int? b) {
  if (b == null) return '';
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String _join(String dir, String name) => dir == '/' ? '/$name' : '$dir/$name';

String _parent(String dir) {
  if (dir == '/' || dir.isEmpty) return '/';
  final i = dir.lastIndexOf('/');
  return i <= 0 ? '/' : dir.substring(0, i);
}

class FilesScreen extends StatefulWidget {
  final ActiveSession session;
  final SSHClient client;
  const FilesScreen({super.key, required this.session, required this.client});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  SftpClient? _sftp;
  String _path = '/';
  List<SftpName> _items = [];
  bool _loading = true;
  String? _error;

  // Transfer progress (null = idle).
  String? _busyLabel;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final sftp = await widget.client.sftp();
      _sftp = sftp;
      final home = await sftp.absolute('.');
      await _load(home);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not start SFTP: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _sftp?.close();
    super.dispose();
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load(String path) async {
    final sftp = _sftp;
    if (sftp == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await sftp.listdir(path);
      final items = list.where((e) => e.filename != '.' && e.filename != '..').toList()
        ..sort((a, b) {
          if (a.attr.isDirectory != b.attr.isDirectory) return a.attr.isDirectory ? -1 : 1;
          return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
        });
      if (!mounted) return;
      setState(() {
        _path = path;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Cannot open $path: $e';
      });
    }
  }

  Future<void> _upload() async {
    final sftp = _sftp;
    if (sftp == null) return;
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withReadStream: true);
    if (result == null) return;
    var done = 0;
    for (final f in result.files) {
      final stream = f.readStream;
      if (stream == null) continue;
      final total = f.size;
      setState(() {
        _busyLabel = 'Uploading ${f.name} (${done + 1}/${result.files.length})';
        _progress = 0;
      });
      try {
        final remote = await sftp.open(_join(_path, f.name),
            mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate);
        await remote.write(
          stream.map((c) => Uint8List.fromList(c)),
          onProgress: (sent) {
            if (mounted && total > 0) setState(() => _progress = sent / total);
          },
        );
        await remote.close();
        done++;
      } catch (e) {
        _msg('Upload of ${f.name} failed: $e');
      }
    }
    if (mounted) setState(() => _busyLabel = null);
    if (done > 0) _msg('Uploaded $done file${done == 1 ? '' : 's'}');
    await _load(_path);
  }

  Future<void> _download(SftpName item) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final size = item.attr.size ?? 0;
    if (size > 200 * 1024 * 1024) {
      final ok = await prompter.confirm(
          'Large file', 'This file is ${_fmtSize(size)}. It is held in memory while downloading '
              'and may fail on low-memory phones. Continue?');
      if (!ok) return;
    }
    setState(() {
      _busyLabel = 'Downloading ${item.filename}';
      _progress = 0;
    });
    try {
      final remote = await sftp.open(_join(_path, item.filename));
      final buffer = BytesBuilder(copy: false);
      var got = 0;
      await for (final chunk in remote.read()) {
        buffer.add(chunk);
        got += chunk.length;
        if (mounted && size > 0) setState(() => _progress = got / size);
      }
      await remote.close();
      if (mounted) setState(() => _busyLabel = null);
      final saved = await FilePicker.platform
          .saveFile(fileName: item.filename, bytes: buffer.takeBytes());
      if (saved != null) _msg('Saved ${item.filename}');
    } catch (e) {
      _msg('Download failed: $e');
    } finally {
      if (mounted) setState(() => _busyLabel = null);
    }
  }

  Future<void> _delete(SftpName item) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final ok = await prompter.confirm(
        'Delete', 'Delete ${item.attr.isDirectory ? 'folder' : 'file'} "${item.filename}"?'
            '${item.attr.isDirectory ? '\n\nThe folder must be empty.' : ''}',
        ok: 'Delete');
    if (!ok) return;
    try {
      final p = _join(_path, item.filename);
      if (item.attr.isDirectory) {
        await sftp.rmdir(p);
      } else {
        await sftp.remove(p);
      }
      await _load(_path);
    } catch (e) {
      _msg('Delete failed: $e');
    }
  }

  Future<void> _rename(SftpName item) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final name = await prompter.ask('Rename', initial: item.filename);
    if (name == null || name.isEmpty || name == item.filename) return;
    try {
      await sftp.rename(_join(_path, item.filename), _join(_path, name));
      await _load(_path);
    } catch (e) {
      _msg('Rename failed: $e');
    }
  }

  Future<void> _newFolder() async {
    final sftp = _sftp;
    if (sftp == null) return;
    final name = await prompter.ask('New folder');
    if (name == null || name.isEmpty) return;
    try {
      await sftp.mkdir(_join(_path, name));
      await _load(_path);
    } catch (e) {
      _msg('Could not create folder: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busyLabel != null;
    return PopScope(
      canPop: _path == '/' || _loading || _error != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _load(_parent(_path));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_path, style: const TextStyle(fontSize: 16)),
          actions: [
            IconButton(
                tooltip: 'Parent folder',
                icon: const Icon(Icons.arrow_upward),
                onPressed: _loading || _path == '/' ? null : () => _load(_parent(_path))),
            IconButton(
                tooltip: 'New folder',
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: _loading || busy ? null : _newFolder),
            IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: _loading || busy ? null : () => _load(_path)),
          ],
          bottom: busy
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(value: _progress))
              : null,
        ),
        floatingActionButton: _sftp == null || busy
            ? null
            : FloatingActionButton.extended(
                onPressed: _upload,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload')),
        body: Column(children: [
          if (busy)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_busyLabel!, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    if (_items.isEmpty) return const Center(child: Text('Empty folder'));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final it = _items[i];
        final dir = it.attr.isDirectory;
        return ListTile(
          leading: Icon(dir ? Icons.folder : Icons.insert_drive_file_outlined),
          title: Text(it.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: dir ? null : Text(_fmtSize(it.attr.size)),
          onTap: dir
              ? () => _load(_join(_path, it.filename))
              : () => _download(it),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'download':
                  _download(it);
                case 'rename':
                  _rename(it);
                case 'delete':
                  _delete(it);
              }
            },
            itemBuilder: (_) => [
              if (!dir) const PopupMenuItem(value: 'download', child: Text('Download')),
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        );
      },
    );
  }
}
