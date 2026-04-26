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
  final guestController = TextEditingController();
  final titleController = TextEditingController();
  
  int pageSize = 20;
  int page = 0;
  
  String? selectedGuest;
  String periodFilter = 'week';
  String statusFilter = 'all';
  String titleSearch = '';
  String? selectedDocType;
  final docTypeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    horizontalScrollController.dispose();
    guestController.dispose();
    titleController.dispose();
    docTypeController.dispose();
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
      var query = supabase
          .from('documents')
          .select('''
            document_id,
            guest_id,
            created_at,
            deleted_at,
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
          ''');

      if (selectedGuest != null && selectedGuest!.isNotEmpty) {
        query = query.ilike('guest_id', '%$selectedGuest%');
      }

      if (titleSearch.trim().isNotEmpty) {
        query = query.ilike('resolved_title', '%${titleSearch.trim()}%');
      }

      if (selectedDocType != null && selectedDocType!.isNotEmpty) {
        query = query.ilike('document_type_label', '%$selectedDocType%');
      }

      if (statusFilter != 'all') {
        if (statusFilter == 'ready_business') {
          query = query.eq('status', 'ready').eq('ocr_status', 'ready');
        } else if (statusFilter == 'review_required') {
          query = query.or('status.eq.review_required,ocr_quality.eq.empty');
        } else if (statusFilter == 'failed_business') {
          query = query.eq('ocr_status', 'failed');
        } else if (statusFilter == 'error_business') {
          query = query.not('processing_error', 'is', null);
        } else if (statusFilter == 'deleted_business') {
          query = query.not('deleted_at', 'is', null);
        } else if (statusFilter == 'processing_business') {
          query = query.or(
            'status.eq.processing,pdf_status.eq.pending,ocr_status.eq.pending',
          );
        }
      }

      final now = DateTime.now();

      if (periodFilter == 'day') {
        final start = DateTime(now.year, now.month, now.day);
        query = query.gte('created_at', start.toIso8601String());
      } else if (periodFilter == 'week') {
        final start = now.subtract(const Duration(days: 7));
        query = query.gte('created_at', start.toIso8601String());
      } else if (periodFilter == 'month') {
        final start = DateTime(now.year, now.month, 1);
        query = query.gte('created_at', start.toIso8601String());
      }

      final docsResp = await query
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
        final docs = List<Map<String, dynamic>>.from(docsResp);
        documents = sortDocuments(docs);
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

  List<Map<String, dynamic>> sortDocuments(List<Map<String, dynamic>> docs) {
    int score(Map<String, dynamic> d) {
      final status = (d['status'] ?? '').toString();
      final ocrStatus = (d['ocr_status'] ?? '').toString();
      final ocrQuality = (d['ocr_quality'] ?? '').toString();
      final error = d['processing_error'];

      if (ocrStatus == 'failed') return 5;
      if (status == 'review_required' || ocrQuality == 'empty') return 4;
      if (error != null && error.toString().isNotEmpty) return 3;
      if (status == 'processing' || ocrStatus == 'pending') return 2;
      if (status == 'ready' && ocrStatus == 'ready') return 1;

      return 0;
    }

    docs.sort((a, b) {
      final s = score(b).compareTo(score(a));
      if (s != 0) return s;

      return (b['created_at'] ?? '')
          .toString()
          .compareTo((a['created_at'] ?? '').toString());
    });

    return docs;
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
              maxWidth: 260,
            ),
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
                loadData();
              },
            ),
          ),
        ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 180,
              maxWidth: 260,
            ),
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
                  page = 0;
                });
                loadData();
              },
            ),
          ),
        ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 180,
              maxWidth: 260,
            ),
            child: TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Titre',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: titleSearch.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          titleController.clear();
                          setState(() {
                            titleSearch = '';
                            page = 0;
                          });
                          loadData();
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                titleSearch = value.trim();
              },
              onSubmitted: (_) {
                setState(() {
                  page = 0;
                });
                loadData();
              },
            ),
          ),
        ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 180,
              maxWidth: 260,
            ),
            child: TextField(
              controller: docTypeController,
              decoration: const InputDecoration(
                labelText: 'Type document',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                selectedDocType = value.trim().isEmpty ? null : value.trim();
              },
              onSubmitted: (_) {
                setState(() {
                  page = 0;
                });
                loadData();
              },
            ),
          ),
ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 180,
              maxWidth: 260,
            ),
            child: DropdownButtonFormField<String>(
              initialValue: statusFilter,
              decoration: const InputDecoration(
                labelText: 'État document',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Tous')),
                DropdownMenuItem(value: 'ready_business', child: Text('Prêt')),
                DropdownMenuItem(value: 'review_required', child: Text('Lecture insuffisante')),
                DropdownMenuItem(value: 'failed_business', child: Text('Échec du traitement')),
                DropdownMenuItem(value: 'error_business', child: Text('Erreur')),
                DropdownMenuItem(value: 'deleted_business', child: Text('Supprimé')),
                DropdownMenuItem(value: 'processing_business', child: Text('Traitement en cours')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  statusFilter = value;
                  page = 0;
                });
                loadData();
              },
            ),
          ),
        OutlinedButton.icon(
          onPressed: () {
            guestController.clear();
            titleController.clear();
            docTypeController.clear();

            setState(() {
              selectedGuest = null;
              titleSearch = '';
              periodFilter = 'week';
              statusFilter = 'all';
              selectedDocType = null;
              page = 0;
            });

            loadData();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Reset'),
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

  Widget mobileDocumentsList() {
    return ListView.builder(
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        final id = doc['document_id']?.toString();
        final cost = costByDocument[id];
        final status = doc['ocr_status']?.toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc['resolved_title']?.toString() ?? '—',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(status ?? '—'),
                      backgroundColor: statusColor(status),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                    Chip(
                      label: Text('${doc['page_count'] ?? '—'} page(s)'),
                    ),
                    Chip(
                      label: Text(money(cost)),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text('Type : ${doc['document_type_label'] ?? '—'}'),
                Text('Entité : ${doc['document_entity'] ?? '—'}'),
                Text('Langue : ${doc['document_language'] ?? '—'}'),
                Text('Date : ${doc['created_at'] ?? '—'}'),
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
      title: 'Documents',
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
                          const SizedBox(height: 12),
                          paginationControls(),
                          const SizedBox(height: 12),
                          Expanded(
                            child: mobileDocumentsList(),
                          ),
                        ],
                      );
                    }

                    return SingleChildScrollView(
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
                                      DataColumn(label: Text('Guest_Id')),
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
                                        DataCell(SelectableText(doc['guest_id']?.toString() ?? '—')),
                                        DataCell(Text(doc['created_at']?.toString() ?? '—')),
                                        DataCell(
                                          SizedBox(
                                            width: 220,
                                            child: SelectableText(
                                              doc['resolved_title']?.toString() ?? '—',
                                              maxLines: 2,
                                            ),
                                          ),
                                        ),
                                        DataCell(SelectableText(doc['document_type_label']?.toString() ?? '—')),
                                        DataCell(SelectableText(doc['document_entity']?.toString() ?? '—')),
                                        DataCell(Text(doc['document_language']?.toString() ?? '—')),
                                        DataCell(SelectableText(doc['page_count']?.toString() ?? '—')),
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
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}