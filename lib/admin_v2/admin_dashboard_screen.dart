import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_layout.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? error;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String money(dynamic value) {
    final number = value is num ? value : num.tryParse(value?.toString() ?? '');
    if (number == null) return '—';
    return '${number.toStringAsFixed(4)} \$';
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await supabase
          .from('v_cost_events_global_summary')
          .select()
          .single();

      setState(() {
        data = Map<String, dynamic>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pilotageCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<_AdminLink> links,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: links.map((link) {
                final enabled = link.route != null;

                return OutlinedButton.icon(
                  onPressed: enabled
                      ? () => Navigator.pushNamed(context, link.route!)
                      : null,
                  icon: Icon(link.icon, size: 18),
                  label: Text(link.label),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardContent() {
    final totalEvents = data?['total_events']?.toString() ?? '—';
    final failedEvents = data?['failed_events']?.toString() ?? '—';
    final totalCost = money(data?['total_cost_usd']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cockpit findAll',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilotage produit, coûts, données, fonctionnalités et traitements.',
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              _summaryCard(
                title: 'Événements traités',
                value: totalEvents,
                icon: Icons.analytics_outlined,
              ),
              const SizedBox(width: 16),
              _summaryCard(
                title: 'Échecs',
                value: failedEvents,
                icon: Icons.warning_amber_outlined,
              ),
              const SizedBox(width: 16),
              _summaryCard(
                title: 'Coût estimé total',
                value: totalCost,
                icon: Icons.payments_outlined,
              ),
            ],
          ),

          const SizedBox(height: 28),

          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 1100 ? 2 : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio:
                MediaQuery.of(context).size.width > 1100 ? 2.4 : 2.1,
            children: [
              _pilotageCard(
                title: 'Pilotage des coûts',
                subtitle:
                    'Suivre les coûts estimés, les coûts providers réels et les écarts mensuels.',
                icon: Icons.euro_outlined,
                links: const [
                  _AdminLink('Coûts', '/admin-costs', Icons.table_chart),
                  _AdminLink('Providers', '/admin-providers', Icons.cloud),
                ],
              ),
              _pilotageCard(
                title: 'Pilotage des données utilisateur',
                subtitle:
                    'Contrôler les documents, les volumes, les statuts et préparer la lecture par utilisateur.',
                icon: Icons.folder_copy_outlined,
                links: const [
                  _AdminLink('Documents', '/admin-docs', Icons.description),
                  _AdminLink('Utilisateurs', null, Icons.people_outline),
                ],
              ),
              _pilotageCard(
                title: 'Pilotage des fonctionnalités',
                subtitle:
                    'Piloter les règles applicatives, la voix, les futures limites et les plans.',
                icon: Icons.tune_outlined,
                links: const [
                  _AdminLink('Voice Rules', '/admin-voice', Icons.mic),
                  _AdminLink('Limites & plans', null, Icons.lock_clock),
                ],
              ),
              _pilotageCard(
                title: 'Pilotage des logs',
                subtitle:
                    'Surveiller les traitements, erreurs, jobs et futurs services critiques.',
                icon: Icons.monitor_heart_outlined,
                links: const [
                  _AdminLink('Jobs', '/admin-jobs', Icons.work_history),
                  _AdminLink('Services tiers', null, Icons.health_and_safety),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Dashboard',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur : $error'),
                )
              : _dashboardContent(),
    );
  }
}

class _AdminLink {
  final String label;
  final String? route;
  final IconData icon;

  const _AdminLink(this.label, this.route, this.icon);
}