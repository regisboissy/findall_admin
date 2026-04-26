import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_layout.dart';

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
  
  final ScrollController horizontalScrollController = ScrollController();

  int pageSize = 20;
  int page = 0;

  String statusFilter = 'all';
  String periodFilter = 'all';
  String guestFilter = '';


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

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final from = page * pageSize;
      final to = from + pageSize - 1;

      final response = await supabase
          .from('processing_jobs')
          .select()
          .order('created_at', ascending: false)
          .range(from, to);

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
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'processing', child: Text('Processing')),
              DropdownMenuItem(value: 'done', child: Text('Done')),
              DropdownMenuItem(value: 'failed', child: Text('Failed')),
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
                guestFilter = value;
                page = 0;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget paginationControls() {
    final hasNext = jobs.length == pageSize;

    return Row(
      children: [
        Text('Jobs — page ${page + 1}'),
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

  Widget mobileJobsList() {
    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final status = job['status']?.toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['job_id']?.toString() ?? '—',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        status ?? '—',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: statusColor(status),
                    ),
                    Chip(
                      label: Text(job['job_type']?.toString() ?? '—'),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text('Document : ${job['document_id'] ?? '—'}'),
                Text('Créé le : ${job['created_at'] ?? '—'}'),

                if (job['last_error'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Erreur : ${job['last_error']}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
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
      title: 'Jobs',
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
                            child: mobileJobsList(),
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
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}