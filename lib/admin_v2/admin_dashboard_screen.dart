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
  Map<String, dynamic>? costData;
  Map<String, dynamic>? liveData;
  Map<String, dynamic>? auditData;

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
      final costResponse = await supabase
          .from('v_cost_events_global_summary')
          .select()
          .single();

      final liveResponse = await supabase
          .from('v_admin_live_dashboard_summary')
          .select()
          .single();

      final auditResponse = await supabase
          .from('v_admin_audit_dashboard_summary')
          .select()
          .single();

      setState(() {
        costData = Map<String, dynamic>.from(costResponse);
        liveData = Map<String, dynamic>.from(liveResponse);
        auditData = Map<String, dynamic>.from(auditResponse);
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return SizedBox(
      width: isMobile
        ? double.infinity
        : 280,
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

  Widget _sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  num number(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
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
    final liveDocuments = liveData?['live_documents']?.toString() ?? '—';
    final liveReview = liveData?['live_documents_to_review']?.toString() ?? '—';
    final livePending = liveData?['live_jobs_pending']?.toString() ?? '—';
    final liveProcessing = liveData?['live_jobs_processing']?.toString() ?? '—';
    final liveFailed = liveData?['live_jobs_failed']?.toString() ?? '—';

    final processedTotal = auditData?['processed_total']?.toString() ?? '—';
    final processedSuccess = auditData?['processed_success']?.toString() ?? '—';
    final processedFailed = auditData?['processed_failed']?.toString() ?? '—';
    final totalPages = auditData?['total_pages']?.toString() ?? '—';
    final failureRate = number(auditData?['failure_rate']);

    final totalCost = money(costData?['total_cost_usd']);
    final totalCostNum = number(costData?['total_cost_usd']);
    final processedTotalNum = number(auditData?['processed_total']);
    final totalPagesNum = number(auditData?['total_pages']);

    final avgCostPerDoc =
        processedTotalNum == 0 ? 0 : totalCostNum / processedTotalNum;

    final avgCostPerPage =
        totalPagesNum == 0 ? 0 : totalCostNum / totalPagesNum;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 0 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cockpit findAll',
            style: TextStyle(
              fontSize: isMobile ? 22 : 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You search, We find...',
            style: TextStyle(
              fontSize: isMobile ? 16 : 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),

          _sectionTitle(
            'État live actuel',
            'Données issues des tables courantes. Peut exclure les documents supprimés définitivement.',
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _summaryCard(
                title: 'Documents visibles',
                value: liveDocuments,
                icon: Icons.description_outlined,
              ),
              _summaryCard(
                title: 'À vérifier',
                value: liveReview,
                icon: Icons.report_problem_outlined,
              ),
              _summaryCard(
                title: 'Jobs pending',
                value: livePending,
                icon: Icons.hourglass_empty,
              ),
              _summaryCard(
                title: 'Jobs processing',
                value: liveProcessing,
                icon: Icons.sync,
              ),
              _summaryCard(
                title: 'Jobs failed',
                value: liveFailed,
                icon: Icons.error_outline,
              ),
            ],
          ),

          const SizedBox(height: 28),

          _sectionTitle(
            'Historique d’analyse',
            'Données issues de document_audit_events. Plus fiable pour les tendances, à alimenter en continu par le worker.',
          ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _summaryCard(
                title: 'Traitements',
                value: processedTotal,
                icon: Icons.analytics_outlined,
              ),
              _summaryCard(
                title: 'Succès',
                value: processedSuccess,
                icon: Icons.check_circle_outline,
              ),
              _summaryCard(
                title: 'Échecs',
                value: processedFailed,
                icon: Icons.warning_amber_outlined,
              ),
              _summaryCard(
                title: 'Pages traitées',
                value: totalPages,
                icon: Icons.layers_outlined,
              ),
              _summaryCard(
                title: 'Taux échec',
                value: '${failureRate.toStringAsFixed(1)} %',
                icon: Icons.percent,
              ),
              _summaryCard(
                title: 'Coût estimé total',
                value: totalCost,
                icon: Icons.payments_outlined,
              ),
              _summaryCard(
                title: 'Coût / traitement',
                value: money(avgCostPerDoc),
                icon: Icons.receipt_long,
              ),
              _summaryCard(
                title: 'Coût / page',
                value: money(avgCostPerPage),
                icon: Icons.calculate_outlined,
              ),
            ],
          ),

          const SizedBox(height: 28),

          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 1100;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
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
                ].map((card) {
                  return SizedBox(
                    width: isDesktop
                        ? (constraints.maxWidth / 2) - 8
                        : constraints.maxWidth,
                    child: card,
                  );
                }).toList(),
              );
            },
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