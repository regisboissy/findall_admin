import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? error;
  List<Map<String, dynamic>> jobs = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await supabase
          .from('processing_jobs')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      setState(() {
        jobs = List<Map<String, dynamic>>.from(response);
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
      case 'done':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'processing':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs / Traitements'),
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
                        columns: const [
                          DataColumn(label: Text('Créé le')),
                          DataColumn(label: Text('Job')),
                          DataColumn(label: Text('Document')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Statut')),
                          DataColumn(label: Text('Erreur')),
                        ],
                        rows: jobs.map((job) {
                          final status = job['status']?.toString();

                          return DataRow(
                            cells: [
                              DataCell(Text(job['created_at']?.toString() ?? '—')),
                              DataCell(Text(job['job_id']?.toString() ?? '—')),
                              DataCell(Text(job['document_id']?.toString() ?? '—')),
                              DataCell(Text(job['job_type']?.toString() ?? '—')),
                              DataCell(
                                Chip(
                                  label: Text(
                                    status ?? '—',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: statusColor(status),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 260,
                                  child: Text(
                                    job['last_error']?.toString() ?? '—',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
    );
  }
}