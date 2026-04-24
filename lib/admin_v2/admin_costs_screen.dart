import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final guestResponse = await supabase
          .from('v_cost_events_by_guest')
          .select()
          .limit(50);

      final documentResponse = await supabase
          .from('v_cost_events_by_document')
          .select()
          .limit(50);

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

  Widget byGuestTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Coût par utilisateur'),
            DataTable(
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
            DataTable(
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coûts'),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      byGuestTable(),
                      const SizedBox(height: 24),
                      byDocumentTable(),
                    ],
                  ),
                ),
    );
  }
}