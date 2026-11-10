import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'editors.dart';
import 'tabs.dart';

/// Connections / Snippets / Identities / Port forwards in tabs.
class ManageScreen extends StatelessWidget {
  final int initialTab;
  const ManageScreen({super.key, this.initialTab = 0});

  Future<void> _add(BuildContext context, int tab) async {
    switch (tab) {
      case 0:
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ConnectionEditScreen()));
      case 1:
        await editSnippet(context);
      case 2:
        await addIdentity(context);
      default:
        if (!store.connections.any((c) => c.type == ConnType.ssh)) {
          snack(context, 'Add an SSH connection first.');
          return;
        }
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ForwardEditScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kBrand,
          foregroundColor: Colors.white,
          title: const Text('Manage'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'CONNECTIONS'),
              Tab(text: 'SNIPPETS'),
              Tab(text: 'IDENTITIES'),
              Tab(text: 'PORT FORWARDS'),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([store, forwards]),
          builder: (context, _) => TabBarView(children: [
            ConnectionsTab(),
            SnippetsTab(),
            IdentitiesTab(),
            ForwardsTab(),
          ]),
        ),
        floatingActionButton: Builder(
          builder: (ctx) => FloatingActionButton(
            backgroundColor: kBrand,
            foregroundColor: Colors.white,
            onPressed: () => _add(ctx, DefaultTabController.of(ctx).index),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }
}
