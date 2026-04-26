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
      final guestFrom = guestPage * pageSize;
      final guestTo = guestFrom + pageSize - 1;

      final documentFrom = documentPage * pageSize;
      final documentTo = documentFrom + pageSize - 1;

      final guestResponse = await supabase
          .from('v_cost_events_by_guest')
          .select()
          .order('total_cost_usd', ascending: false)
          .range(guestFrom, guestTo);

      final documentResponse = await supabase
          .from('v_cost_events_by_document')
          .select()
          .order('total_cost_usd', ascending: false)
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
    return Row(
      children: [
        DropdownButton<String>(
          value: period,
          items: const [
            DropdownMenuItem(value: 'day', child: Text('Jour')),
            DropdownMenuItem(value: 'week', child: Text('Semaine')),
            DropdownMenuItem(value: 'month', child: Text('Mois')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => period = value);
            loadData();
          },
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 200,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Guest ID',
            ),
            onChanged: (value) {
              selectedGuest = value.isEmpty ? null : value;
            },
            onSubmitted: (_) => loadData(),
          ),
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
                          DataCell(Text(row['guest_id']?.toString() ?? '—')),
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
                      DataColumn(label: Text('Document')),
                      DataColumn(label: Text('Events')),
                      DataColumn(label: Text('Succès')),
                      DataColumn(label: Text('Pages')),
                      DataColumn(label: Text('PDF bytes')),
                      DataColumn(label: Text('Coût total')),
                    ],
                    rows: byDocument.map((row) {
                      return DataRow(
                        cells: [
                          DataCell(Text(row['document_id']?.toString() ?? '—')),
                          DataCell(Text(row['total_events']?.toString() ?? '—')),
                          DataCell(Text(row['success']?.toString() ?? '—')),
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