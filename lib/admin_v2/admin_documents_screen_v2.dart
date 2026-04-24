import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    loadData();
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
          .limit(50);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadData,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur : $error'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                          final id =
                              doc['document_id']?.toString();
                          final cost = costByDocument[id];

                          return DataRow(cells: [
                            DataCell(Text(
                                doc['created_at']?.toString() ?? '—')),
                            DataCell(
                              SizedBox(
                                width: 220,
                                child: Text(
                                  doc['resolved_title']?.toString() ?? '—',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(Text(
                                doc['document_type_label']?.toString() ??
                                    '—')),
                            DataCell(Text(
                                doc['document_entity']?.toString() ??
                                    '—')),
                            DataCell(Text(
                                doc['document_language']?.toString() ??
                                    '—')),
                            DataCell(Text(
                                doc['page_count']?.toString() ?? '—')),
                            DataCell(
                              Chip(
                                label: Text(
                                  doc['ocr_status']?.toString() ?? '—',
                                  style: const TextStyle(
                                      color: Colors.white),
                                ),
                                backgroundColor: statusColor(
                                    doc['ocr_status']?.toString()),
                              ),
                            ),
                            DataCell(Text(money(cost))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
    );
  }
}