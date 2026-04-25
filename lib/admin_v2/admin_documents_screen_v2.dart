import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_layout.dart';

class AdminDocumentsScreenV2 extends StatefulWidget {
  const AdminDocumentsScreenV2({super.key});

  @override
  State<AdminDocumentsScreenV2> createState() =>
      _AdminDocumentsScreenV2State();
}

class _AdminDocumentsScreenV2State
    extends State<AdminDocumentsScreenV2> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? error;

  List<Map<String, dynamic>> documents = [];
  Map<String, double> costByDocument = {};
  final ScrollController horizontalScrollController = ScrollController();
  
  int pageSize = 20;
  int page = 0;
  
  String? selectedGuest;
  String periodFilter = 'all';
  String statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    horizontalScrollController.dispose();
    super.dispose();
  }

  String money(double? value) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(4)} \$';
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final docsResp = await supabase
          .from('documents')
          .select('''
            document_id,
            guest_id,
            created_at,
            status,
            ocr_status,
            ocr_quality,
            resolved_title,
            document_type_core,
            document_type_label,
            document_entity,
            document_date,
            document_language,
            page_count,
            pdf_status,
            processing_step,
            processing_error
          ''')
          .order('created_at', ascending: false)
          .range(page * pageSize, (page * pageSize) + pageSize - 1);

      final costResp = await supabase
          .from('v_cost_events_by_document')
          .select('document_id, total_cost_usd');

      final costMap = <String, double>{};
      for (final row in costResp) {
        final id = row['document_id']?.toString();
        final val = row['total_cost_usd'];
        if (id != null && val != null) {
          final n = val is num
              ? val.toDouble()
              : double.tryParse(val.toString());
          if (n != null) costMap[id] = n;
        }
      }

      setState(() {
        documents = List<Map<String, dynamic>>.from(docsResp);
        costByDocument = costMap;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Color statusColor(String? status) {
    switch (status) {
      case 'ready':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget filters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            initialValue: periodFilter,
            decoration: const InputDecoration(
              labelText: 'Période',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Toutes')),
              DropdownMenuItem(value: 'day', child: Text('Aujourd’hui')),
              DropdownMenuItem(value: 'week', child: Text('Cette semaine')),
              DropdownMenuItem(value: 'month', child: Text('Ce mois')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                periodFilter = value;
                page = 0;
              });
            },
          ),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Guest ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                selectedGuest = value.trim().isEmpty ? null : value.trim();
                page = 0;
              });
            },
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            initialValue: statusFilter,
            decoration: const InputDecoration(
              labelText: 'Statut',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tous')),
              DropdownMenuItem(value: 'ready', child: Text('Ready')),
              DropdownMenuItem(value: 'failed', child: Text('Failed')),
              DropdownMenuItem(value: 'processing', child: Text('Processing')),
              DropdownMenuItem(value: 'review_required', child: Text('À vérifier')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                statusFilter = value;
                page = 0;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget paginationControls() {
    final hasNext = documents.length == pageSize;

    return Row(
      children: [
        Text('Page ${page + 1}'),
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
              page = 0;
            });

            loadData();
          },
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: page > 0
              ? () {
                  setState(() => page--);
                  loadData();
                }
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: hasNext
              ? () {
                  setState(() => page++);
                  loadData();
                }
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Documents',
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur : $error'),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      filters(),
                      const SizedBox(height: 12),
                      paginationControls(),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Scrollbar(
                            controller: horizontalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 16,
                                columns: const [
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Titre')),
                                  DataColumn(label: Text('Type')),
                                  DataColumn(label: Text('Entité')),
                                  DataColumn(label: Text('Langue')),
                                  DataColumn(label: Text('Pages')),
                                  DataColumn(label: Text('Statut')),
                                  DataColumn(label: Text('Coût')),
                                ],
                                rows: documents.map((doc) {
                                final id = doc['document_id']?.toString();
                                final cost = costByDocument[id];

                                return DataRow(cells: [
                                  DataCell(Text(doc['created_at']?.toString() ?? '—')),
                                  DataCell(
                                    SizedBox(
                                      width: 220,
                                      child: Text(
                                        doc['resolved_title']?.toString() ?? '—',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(doc['document_type_label']?.toString() ?? '—')),
                                  DataCell(Text(doc['document_entity']?.toString() ?? '—')),
                                  DataCell(Text(doc['document_language']?.toString() ?? '—')),
                                  DataCell(Text(doc['page_count']?.toString() ?? '—')),
                                  DataCell(
                                    Chip(
                                      label: Text(
                                        doc['ocr_status']?.toString() ?? '—',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: statusColor(doc['ocr_status']?.toString()),
                                    ),
                                  ),
                                  DataCell(Text(money(cost))),
                                ]);
                              }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ]
                  ),
                ),
    );
  }
}