import 'package:flutter/material.dart';

class AdminLayout extends StatelessWidget {
  final String title;
  final Widget child;

  const AdminLayout({
    super.key,
    required this.title,
    required this.child,
  });

  bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 900;
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: desktop
            ? null
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
      ),
      drawer: desktop ? null : const _AdminDrawer(),
      body: Row(
        children: [
          if (desktop) const _AdminSidebar(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: const _MenuContent(),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    return const Drawer(
      child: _MenuContent(),
    );
  }
}

class _MenuContent extends StatelessWidget {
  const _MenuContent();

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget item(
    BuildContext context,
    String label,
    String route,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pushReplacementNamed(context, route);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 16),

        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'findAll Admin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),

        sectionTitle('Pilotage des coûts'),
        item(context, 'Coûts', '/admin-costs', Icons.table_chart),
        item(context, 'Providers', '/admin-providers', Icons.cloud),

        sectionTitle('Données utilisateur'),
        item(context, 'Documents', '/admin-docs', Icons.description),

        sectionTitle('Fonctionnalités'),
        item(context, 'Voice Rules', '/admin-voice', Icons.mic),

        sectionTitle('Logs & traitements'),
        item(context, 'Jobs', '/admin-jobs', Icons.work_history),

        const Divider(),

        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Déconnexion'),
          onTap: () {
            // on fera le logout plus tard
          },
        ),
      ],
    );
  }
}