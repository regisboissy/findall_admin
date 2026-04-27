import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLayout extends StatefulWidget {
  final String title;
  final Widget child;

  const AdminLayout({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  //delais deconnexion timeout
  static const Duration _inactiveTimeout = Duration(minutes: 2);

  Timer? _inactiveTimer;

  bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 900;
  }

  @override
  void initState() {
    super.initState();
    _resetInactiveTimer();
  }

  @override
  void dispose() {
    _inactiveTimer?.cancel();
    super.dispose();
  }

  void _resetInactiveTimer() {
    _inactiveTimer?.cancel();
    _inactiveTimer = Timer(_inactiveTimeout, _signOutForInactivity);
  }

  Future<void> _signOutForInactivity() async {
    if (!mounted) return;

    await Supabase.instance.client.auth.signOut(
      scope: SignOutScope.global,
    );

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactiveTimer(),
      onPointerMove: (_) => _resetInactiveTimer(),
      onPointerSignal: (_) => _resetInactiveTimer(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
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
                child: widget.child,
              ),
            ),
          ],
        ),
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

class _MenuContent extends StatefulWidget {
  const _MenuContent();

  @override
  State<_MenuContent> createState() => _MenuContentState();
}

class _MenuContentState extends State<_MenuContent> {
  bool _isLoggingOut = false;

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
        if (isActive) return;

        final navigator = Navigator.of(context);
        final scaffold = Scaffold.maybeOf(context);

        if (scaffold?.isDrawerOpen ?? false) {
          navigator.pop(); // ferme le drawer
        }

        navigator.pushReplacementNamed(route);
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
    final userEmail = Supabase.instance.client.auth.currentUser?.email;

    return ListView(
      children: [
        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'findAll Admin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (userEmail != null) ...[
                const SizedBox(height: 4),
                Text(
                  userEmail,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
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
          leading: Icon(_isLoggingOut ? Icons.hourglass_empty : Icons.logout),
          title: Text(_isLoggingOut ? 'Déconnexion...' : 'Déconnexion'),
          enabled: !_isLoggingOut,
          onTap: () async {
            if (_isLoggingOut) return;

            setState(() {
              _isLoggingOut = true;
            });

            final navigator = Navigator.of(context);
            final scaffold = Scaffold.maybeOf(context);
            final scaffoldMessenger = ScaffoldMessenger.of(context);

            if (scaffold?.isDrawerOpen ?? false) {
              navigator.pop();
            }

            try {
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Déconnexion en cours...')),
              );

              await Supabase.instance.client.auth.signOut(
                scope: SignOutScope.global,
              );

              if (!mounted) return;

              navigator.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            } catch (e) {
              if (!mounted) return;

              setState(() {
                _isLoggingOut = false;
              });

              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Erreur lors de la déconnexion'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ],
    );
  }
}