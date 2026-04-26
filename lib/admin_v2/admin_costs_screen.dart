import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

import 'admin_layout.dart';

class AdminCostsScreen extends StatefulWidget {
  const AdminCostsScreen({super.key});

  @override
  State<AdminCostsScreen> createState() => _AdminCostsScreenState();
}

class _AdminCostsScreenState extends State<AdminCostsScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? error;

  List<Map<String, dynamic>> byGuest = [];
  List<Map<String, dynamic>> byDocument = [];
  
  int pageSize = 20;
  int guestPage = 0;
  int documentPage = 0;
  
  String? selectedGuest;
  DateTime? selectedDate;
  String period = 'month'; // day / week / month

  final guestController = TextEditingController();

  double maxCostSmallDocument = 0.02;
  double maxCostFailedDocument = 0.01;
  int smallDocumentPageLimit = 2;

  final maxCostSmallDocController = TextEditingController(text: '0.02');
  final maxCostFailedDocController = TextEditingController(text: '0.01');
  final smallDocPageLimitController = TextEditingController(text: '2');

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    guestController.dispose();
    maxCostSmallDocController.dispose();
    maxCostFailedDocController.dispose();
    smallDocPageLimitController.dispose();
    super.dispose();
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
      final guestFrom = guestPage * pageSize;
      final guestTo = guestFrom + pageSize - 1;

      final documentFrom = documentPage * pageSize;
      final documentTo = documentFrom + pageSize - 1;

      final now = DateTime.now();

      late DateTime start;
      late DateTime end;

      if (period == 'day') {
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
      } else if (period == 'week') {
        start = now.subtract(const Duration(days: 7));
        end = now;
      } else {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
      }

      final params = {
        'p_start': start.toIso8601String(),
        'p_end': end.toIso8601String(),
        'p_guest': selectedGuest,
      };

      final guestResponse = await supabase
          .rpc('rpc_admin_costs_by_guest', params: params)
          .range(guestFrom, guestTo);

      final documentResponse = await supabase
          .rpc('rpc_admin_costs_by_document', params: params)
          .range(documentFrom, documentTo);

      setState(() {
        byGuest = List<Map<String, dynamic>>.from(guestResponse);
        byDocument = List<Map<String, dynamic>>.from(documentResponse);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget filters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 180,
            maxWidth: 220,
          ),
          child: DropdownButtonFormField<String>(
            initialValue: period,
            decoration: const InputDecoration(
              labelText: 'Période',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'day', child: Text('Jour')),
              DropdownMenuItem(value: 'week', child: Text('Semaine')),
              DropdownMenuItem(value: 'month', child: Text('Mois')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                period = value;
                guestPage = 0;
                documentPage = 0;
              });
              loadData();
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 240,
          child: TextField(
            controller: guestController,
            decoration: const InputDecoration(
              labelText: 'Guest ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              selectedGuest = value.trim().isEmpty ? null : value.trim();
            },
            onSubmitted: (_) {
              setState(() {
                guestPage = 0;
                documentPage = 0;
              });
              loadData();
            },
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            guestController.clear();

            setState(() {
              selectedGuest = null;
              period = 'month';
              guestPage = 0;
              documentPage = 0;
            });

            loadData();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
        ),
      ],
    );
  }

  Widget paginationControls({
    required String label,
    required int page,
    required bool hasNext,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
  }) {
    return Row(
      children: [
        Text('$label — page ${page + 1}'),
        const Spacer(),
        DropdownButton<int>(
          value: pageSize,
          items: const [
            DropdownMenuItem(value: 20, child: Text('20')),
            DropdownMenuItem(value: 50, child: Text('50')),
            DropdownMenuItem(value: 100, child: Text('100')),
          ],
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              pageSize = value;
              guestPage = 0;
              documentPage = 0;
            });

            loadData();
          },
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: page > 0 ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: hasNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget byGuestTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Coût par utilisateur'),
            paginationControls(
              label: 'Utilisateurs',
              page: guestPage,
              hasNext: byGuest.length == pageSize,
              onPrevious: () {
                setState(() {
                  guestPage--;
                });
                loadData();
              },
              onNext: () {
                setState(() {
                  guestPage++;
                });
                loadData();
              },
            ),
            const SizedBox(height: 12),
            ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: Scrollbar(
                thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Guest')),
                      DataColumn(label: Text('Events')),
                      DataColumn(label: Text('Succès')),
                      DataColumn(label: Text('Erreurs')),
                      DataColumn(label: Text('Coût total')),
                      DataColumn(label: Text('Coût moyen')),
                    ],
                    rows: byGuest.map((row) {
                      return DataRow(
                        cells: [
                          DataCell(SelectableText(row['guest_id']?.toString() ?? '—')),
                          DataCell(Text(row['total_events']?.toString() ?? '—')),
                          DataCell(Text(row['success_events']?.toString() ?? '—')),
                          DataCell(Text(row['failed_events']?.toString() ?? '—')),
                          DataCell(Text(money(row['total_cost_usd']))),
                          DataCell(Text(money(row['avg_cost_per_event_usd']))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget byDocumentTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Coût par document'),
            paginationControls(
              label: 'Documents',
              page: documentPage,
              hasNext: byDocument.length == pageSize,
              onPrevious: () {
                setState(() {
                  documentPage--;
                });
                loadData();
              },
              onNext: () {
                setState(() {
                  documentPage++;
                });
                loadData();
              },
            ),
            const SizedBox(height: 12),
            ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.touch,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                    columns: const [
                      DataColumn(label: Text('⚠️')),
                      DataColumn(label: Text('Document')),
                      DataColumn(label: Text('Events')),
                      DataColumn(label: Text('Succès')),
                      DataColumn(label: Text('Erreurs')),
                      DataColumn(label: Text('Pages')),
                      DataColumn(label: Text('PDF bytes')),
                      DataColumn(label: Text('Coût total')),
                    ],
                    rows: byDocument.map((row) {
                      final pages = row['pages'] is num
                          ? (row['pages'] as num).toInt()
                          : int.tryParse(row['pages']?.toString() ?? '') ?? 0;

                      final cost = row['total_cost_usd'] is num
                          ? (row['total_cost_usd'] as num).toDouble()
                          : double.tryParse(row['total_cost_usd']?.toString() ?? '') ?? 0;

                      final failed = row['failed_events'] is num
                          ? (row['failed_events'] as num).toInt()
                          : int.tryParse(row['failed_events']?.toString() ?? '') ?? 0;

                      bool anomaly = false;

                      // 🔴 petit document mais coûteux
                      if (pages <= smallDocumentPageLimit && cost > maxCostSmallDocument) {
                        anomaly = true;
                      }

                      // 🔴 document avec erreurs + coût
                      if (failed > 0 && cost > maxCostFailedDocument) {
                        anomaly = true;
                      }
                      return DataRow(
                        color: anomaly
                            ? WidgetStateProperty.all(
                                Colors.orange.withValues(alpha:0.05),
                              )
                            : null,
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 40,
                              child: Center(
                                child: anomaly
                                    ? const Icon(Icons.warning, color: Colors.orange, size: 18)
                                    : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          DataCell(SelectableText(row['document_id']?.toString() ?? '—')),
                          DataCell(Text(row['total_events']?.toString() ?? '—')),
                          DataCell(Text(row['success']?.toString() ?? '—')),
                          DataCell(Text(row['failed_events']?.toString() ?? '—')),
                          DataCell(Text(row['pages']?.toString() ?? '—')),
                          DataCell(Text(row['pdf_size_bytes']?.toString() ?? '—')),
                          DataCell(Text(money(row['total_cost_usd']))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget mobileGuestCosts() {
    return ListView.builder(
      itemCount: byGuest.length,
      itemBuilder: (context, index) {
        final row = byGuest[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['guest_id']?.toString() ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Events ${row['total_events'] ?? '—'}')),
                    Chip(label: Text('OK ${row['success_events'] ?? '—'}')),
                    Chip(label: Text('KO ${row['failed_events'] ?? '—'}')),
                  ],
                ),

                const SizedBox(height: 8),

                Text('Coût total : ${money(row['total_cost_usd'])}'),
                Text('Coût moyen : ${money(row['avg_cost_per_event_usd'])}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget mobileDocumentCosts() {
    return ListView.builder(
      itemCount: byDocument.length,
      itemBuilder: (context, index) {
        final row = byDocument[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['document_id']?.toString() ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Events ${row['total_events'] ?? '—'}')),
                    Chip(label: Text('Pages ${row['pages'] ?? '—'}')),
                  ],
                ),

                const SizedBox(height: 8),

                Text('Taille PDF : ${row['pdf_size_bytes'] ?? '—'}'),
                Text('Coût total : ${money(row['total_cost_usd'])}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget anomalyControls() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Seuils anomalies',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),

            SizedBox(
              width: 180,
              child: TextField(
                controller: smallDocPageLimitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Petit doc ≤ pages',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) {
                  setState(() {
                    smallDocumentPageLimit =
                        int.tryParse(smallDocPageLimitController.text) ?? 2;
                  });
                },
              ),
            ),

            SizedBox(
              width: 190,
              child: TextField(
                controller: maxCostSmallDocController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Coût max petit doc',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) {
                  setState(() {
                    maxCostSmallDocument = double.tryParse(
                          maxCostSmallDocController.text.replaceAll(',', '.'),
                        ) ??
                        0.02;
                  });
                },
              ),
            ),

            SizedBox(
              width: 210,
              child: TextField(
                controller: maxCostFailedDocController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Coût max doc KO',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) {
                  setState(() {
                    maxCostFailedDocument = double.tryParse(
                          maxCostFailedDocController.text.replaceAll(',', '.'),
                        ) ??
                        0.01;
                  });
                },
              ),
            ),

            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  smallDocumentPageLimit =
                      int.tryParse(smallDocPageLimitController.text.trim()) ?? 2;

                  maxCostSmallDocument = double.tryParse(
                        maxCostSmallDocController.text.trim().replaceAll(',', '.'),
                      ) ??
                      0.02;

                  maxCostFailedDocument = double.tryParse(
                        maxCostFailedDocController.text.trim().replaceAll(',', '.'),
                      ) ??
                      0.01;
                });
              },
              icon: const Icon(Icons.tune),
              label: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboardSummary() {
    final totalCost = byGuest.fold<double>(
      0,
      (sum, g) => sum + (g['total_cost_usd'] ?? 0),
    );

    final totalDocs = byDocument.length;

    final totalFailed = byDocument.fold<int>(
      0,
      (sum, d) => sum + ((d['failed_events'] ?? 0) as int),
    );

    final totalEvents = byDocument.fold<int>(
      0,
      (sum, d) => sum + ((d['total_events'] ?? 0) as int),
    );

    final failureRate =
        totalEvents == 0 ? 0 : (totalFailed / totalEvents) * 100;

    final avgCost =
        totalDocs == 0 ? 0 : totalCost / totalDocs;

    final topUser = byGuest.isNotEmpty ? byGuest.first : null;
    final topDoc = byDocument.isNotEmpty ? byDocument.first : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            _kpi('Coût total', money(totalCost)),
            _kpi('Documents', '$totalDocs'),
            _kpi('Taux échec', '${failureRate.toStringAsFixed(1)} %'),
            _kpi('Coût moyen', money(avgCost)),

            if (topUser != null)
              _kpi(
                'Top user',
                '${topUser['guest_id']} (${money(topUser['total_cost_usd'])})',
              ),

            if (topDoc != null)
              _kpi(
                'Top document',
                '${topDoc['document_id']} (${money(topDoc['total_cost_usd'])})',
              ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Vue coûts',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur : $error'),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 700;

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          filters(),
                          const SizedBox(height: 16),

                          Expanded(
                            child: DefaultTabController(
                              length: 2,
                              child: Column(
                                children: [
                                  const TabBar(
                                    tabs: [
                                      Tab(text: 'Users'),
                                      Tab(text: 'Documents'),
                                    ],
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        mobileGuestCosts(),
                                        mobileDocumentCosts(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Desktop = inchangé
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          filters(),
                          const SizedBox(height: 12),
                          dashboardSummary(),
                          const SizedBox(height: 12),
                          anomalyControls(),
                          const SizedBox(height: 24),
                          byGuestTable(),
                          const SizedBox(height: 24),
                          byDocumentTable(),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}