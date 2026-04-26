import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
              padding: EdgeInsets.all(
                MediaQuery.of(context).size.width < 600 ? 12 : 24,
              ),
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

  String currentRoute(BuildContext context) {
    return ModalRoute.of(context)?.settings.name ?? '';
  }

  Widget section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
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
    final isActive = currentRoute(context) == route;

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: isActive,
      selectedTileColor: Colors.grey.shade200,
      onTap: () {
        final navigator = Navigator.of(context);
        final scaffold = Scaffold.maybeOf(context);

        if (scaffold?.isDrawerOpen ?? false) {
          navigator.pop(); // ferme le drawer
        }

        if (!isActive) {
          navigator.pushReplacementNamed(route);
        }
      },
    );
  }

  Widget disabledItem(String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey),
      title: Text(label, style: const TextStyle(color: Colors.grey)),
      enabled: false,
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

        section('Accueil'),
        item(context, 'Cockpit', '/admin', Icons.dashboard),

        section('Coûts'),
        item(context, 'Vue coûts', '/admin-costs', Icons.table_chart),
        item(context, 'Providers', '/admin-providers', Icons.cloud),

        section('Données'),
        item(context, 'Documents', '/admin-docs', Icons.description),
        disabledItem('Utilisateurs', Icons.people_outline),

        section('Fonctionnalités'),
        item(context, 'Voice Rules', '/admin-voice', Icons.mic),
        disabledItem('Limites & plans', Icons.lock_clock),

        section('Supervision'),
        item(context, 'Jobs', '/admin-jobs', Icons.work_history),
        disabledItem('Services tiers', Icons.health_and_safety),

        const Divider(),

        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Déconnexion'),
          onTap: () async {
            final navigator = Navigator.of(context);

            await Supabase.instance.client.auth.signOut();

            navigator.pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          },
        ),
      ],
    );
  }
}