import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../store.dart';
import 'manage_screen.dart';
import 'settings_screen.dart';
import 'terminal_screen.dart';

const _titleColor = Color(0xFF0F3341);
const _subtitleColor = Color(0xFF5B6E75);
const _iconColor = Color(0xFF666666);

/// Main menu: Quick Connect, Frequently Used, Manage Connections, ...
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _quickConnect(BuildContext context) async {
    final text = await prompter.ask('Quick connect  (user@host:port)');
    if (text == null || text.trim().isEmpty || !context.mounted) return;
    var host = text.trim();
    var user = '';
    var port = 22;
    final at = host.lastIndexOf('@');
    if (at >= 0) {
      user = host.substring(0, at);
      host = host.substring(at + 1);
    }
    final colon = host.lastIndexOf(':');
    if (colon > 0) {
      port = int.tryParse(host.substring(colon + 1)) ?? 22;
      host = host.substring(0, colon);
    }
    openExisting(
        context, sessions.open(Connection(id: newId(), host: host, port: port, username: user)));
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        toolbarHeight: 76,
        elevation: 4,
        shadowColor: Colors.black54,
        title: const Text(appName,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => showAboutDialog(
              context: context,
              applicationName: appName,
              applicationVersion: '0.1.0',
              applicationLegalese: 'SSH, Telnet and local terminal for Android',
            ),
            itemBuilder: (_) => const [PopupMenuItem(value: 'about', child: Text('About'))],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, sessions]),
        builder: (context, _) {
          final frequent = store.connections.where((c) => c.useCount > 0).toList()
            ..sort((a, b) => b.useCount.compareTo(a.useCount));
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            children: [
              if (sessions.sessions.isNotEmpty) ...[
                _MenuItem(
                  title: 'Active Sessions',
                  subtitle: '${sessions.sessions.length} open — tap one to return',
                  icon: Icons.terminal,
                ),
                for (final s in sessions.sessions)
                  _SubItem(
                    icon: s.connected ? Icons.link : Icons.link_off,
                    title: s.title,
                    subtitle: s.connected ? 'Connected' : (s.finished ? 'Disconnected' : 'Connecting…'),
                    onTap: () => openExisting(context, s),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, color: _iconColor),
                      onPressed: () => sessions.close(s),
                    ),
                  ),
                const SizedBox(height: 24),
              ],
              _MenuItem(
                title: 'Quick Connect',
                subtitle: 'Connect to a new host',
                icon: Icons.bolt,
                onTap: () => _quickConnect(context),
              ),
              const SizedBox(height: 24),
              _MenuItem(
                title: 'Frequently Used',
                subtitle: 'Your most used connections',
                icon: Icons.star,
              ),
              if (frequent.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(36, 4, 24, 8),
                  child: Text('Connections you use will appear here.',
                      style: TextStyle(color: _subtitleColor, fontSize: 16)),
                ),
              for (final c in frequent.take(5))
                _SubItem(
                  icon: Icons.public,
                  title: c.label,
                  subtitle: 'Connected ${c.useCount} ${c.useCount == 1 ? 'time' : 'times'}',
                  onTap: () => openSession(context, c),
                ),
              const SizedBox(height: 24),
              _MenuItem(
                title: 'Manage Connections',
                subtitle: 'Manage your connections and identities',
                icon: Icons.public,
                onTap: () => _push(context, const ManageScreen()),
              ),
              const SizedBox(height: 24),
              _MenuItem(
                title: 'Port Forwards',
                subtitle: 'Local and remote tunnels',
                icon: Icons.swap_horiz,
                onTap: () => _push(context, const ManageScreen(initialTab: 3)),
              ),
              const SizedBox(height: 24),
              _MenuItem(
                title: 'Settings',
                subtitle: 'Personalise your sessions',
                icon: Icons.settings,
                onTap: () => _push(context, const SettingsScreen()),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  const _MenuItem({required this.title, required this.subtitle, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 14, 28, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 26, color: _titleColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 17, color: _subtitleColor)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Icon(icon, size: 44, color: _iconColor),
          ],
        ),
      ),
    );
  }
}

class _SubItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  const _SubItem(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(44, 10, 16, 10),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: _iconColor, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 24, color: _titleColor)),
                  Text(subtitle, style: const TextStyle(fontSize: 17, color: _subtitleColor)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
