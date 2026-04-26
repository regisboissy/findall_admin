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
  bool errorsOnly = false;
  
  final ScrollController horizontalScrollController = ScrollController();
  final guestController = TextEditingController();

  int pageSize = 20;
  int page = 0;

  String statusFilter = 'all';
  String periodFilter = 'week';
  String guestFilter = '';


  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    horizontalScrollController.dispose();
    guestController.dispose();
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

      var query = supabase
          .from('processing_jobs')
          .select();

      // 🔹 Guest ID
      if (guestFilter.trim().isNotEmpty) {
        query = query.ilike('guest_id', '%${guestFilter.trim()}%');
      }

      // 🔹 Statut
      if (statusFilter != 'all') {
        query = query.eq('status', statusFilter);
      }

      if (errorsOnly) {
        query = query.or('status.eq.failed,last_error.not.is.null');
      }

      // 🔹 Période
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

      // 🔹 Pagination + tri
      final response = await query
          .order('created_at', ascending: false)
          .range(from, to);

      setState(() {
        final list = List<Map<String, dynamic>>.from(response);
        jobs = sortJobs(list);
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

  bool isStuckJob(Map<String, dynamic> job) {
    final status = job['status']?.toString();
    final createdAtRaw = job['created_at']?.toString();

    if (createdAtRaw == null || createdAtRaw.isEmpty) return false;

    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) return false;

    final diff = DateTime.now().difference(createdAt);

    if (status == 'processing' && diff.inMinutes > 10) return true;
    if (status == 'pending' && diff.inMinutes > 5) return true;

    return false;
  }

  Widget statusChip(Map<String, dynamic> job) {
    final status = job['status']?.toString();
    final stuck = isStuckJob(job);

    return Chip(
      label: Text(
        stuck ? 'STUCK' : (status ?? '—'),
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: stuck ? Colors.deepOrange : statusColor(status),
    );
  }



  List<Map<String, dynamic>> sortJobs(List<Map<String, dynamic>> jobs) {
    int score(Map<String, dynamic> j) {
      final status = (j['status'] ?? '').toString();
      final error = j['last_error'];
      final createdAtStr = j['created_at']?.toString();

      DateTime? createdAt;
      if (createdAtStr != null) {
        createdAt = DateTime.tryParse(createdAtStr);
      }

      final now = DateTime.now();

      if (status == 'failed') return 6;
      if (error != null && error.toString().isNotEmpty) return 5;

      if (createdAt != null) {
        final diff = now.difference(createdAt);

        if (status == 'processing' && diff.inMinutes > 10) return 4;
        if (status == 'pending' && diff.inMinutes > 5) return 3;
      }

      if (status == 'processing') return 2;
      if (status == 'pending') return 1;
      if (status == 'done') return 0;

      return 0;
    }

    jobs.sort((a, b) {
      final s = score(b).compareTo(score(a));
      if (s != 0) return s;

      return (b['created_at'] ?? '')
          .toString()
          .compareTo((a['created_at'] ?? '').toString());
    });

    return jobs;
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
              loadData();
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
              loadData();
            },
          ),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            controller: guestController,
            decoration: const InputDecoration(
              labelText: 'Guest ID',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              guestFilter = value;
            },

            onSubmitted: (_) {
              setState(() {
                page = 0;
              });
              loadData();
            },
          ),
        ),
        FilterChip(
          label: const Text('Erreurs seulement'),
          selected: errorsOnly,
          onSelected: (value) {
            setState(() {
              errorsOnly = value;
              page = 0;
            });
            loadData();
          },
        ),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              periodFilter = 'week';
              statusFilter = 'all';
              guestFilter = '';
              guestController.clear();
              errorsOnly = false;
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
                    statusChip(job),
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

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(job['created_at']?.toString() ?? '—')),
                                          DataCell(SelectableText(job['job_id']?.toString() ?? '—')),
                                          DataCell(SelectableText(job['document_id']?.toString() ?? '—')),
                                          DataCell(SelectableText(job['job_type']?.toString() ?? '—')),
                                          DataCell(statusChip(job)),
                                          DataCell(
                                            SizedBox(
                                              width: 420,
                                              child: SelectableText(
                                                job['last_error']?.toString() ?? '—',
                                                maxLines: 3,
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