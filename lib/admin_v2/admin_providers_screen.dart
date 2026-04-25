import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProvidersScreen extends StatefulWidget {
  const AdminProvidersScreen({super.key});

  @override
  State<AdminProvidersScreen> createState() => _AdminProvidersScreenState();
}

class _AdminProvidersScreenState extends State<AdminProvidersScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? error;

  DateTime selectedMonth = DateTime.now();

  final List<String> providers = [
    'google_vision',
    'openai',
    'railway',
    'supabase',
  ];

  Map<String, Map<String, dynamic>?> data = {};

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

  String monthKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-01";
  }

  Future<void> loadData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final month = monthKey(selectedMonth);

      final res = await supabase
          .from('provider_usage_snapshots')
          .select()
          .eq('period_month', month);

      final rows = List<Map<String, dynamic>>.from(res);

      final map = <String, Map<String, dynamic>?>{};

      for (final p in providers) {
        map[p] = rows.firstWhere(
          (e) => e['provider'] == p,
          orElse: () => {},
        );
        if (map[p]!.isEmpty) map[p] = null;
      }

      setState(() {
        data = map;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> openEditDialog(String provider) async {
    final existing = data[provider];

    final costCtrl = TextEditingController(
      text: existing?['total_cost_usd']?.toString() ?? '',
    );

    final commentCtrl = TextEditingController(
      text: existing?['comment']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(existing == null
              ? 'Créer $provider'
              : 'Modifier $provider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Coût USD'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(labelText: 'Commentaire'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final cost = double.tryParse(costCtrl.text.trim());
                if (cost == null) return;

                final month = monthKey(selectedMonth);

                if (existing == null) {
                  // CREATE
                  await supabase.from('provider_usage_snapshots').insert({
                    'provider': provider,
                    'total_cost_usd': cost,
                    'period_start': month,
                    'period_end': month,
                    'period_month': month,
                    'is_validated': true,
                    'source': 'admin_manual',
                    'comment': commentCtrl.text,
                  });
                } else {
                  // UPDATE
                  await supabase
                      .from('provider_usage_snapshots')
                      .update({
                        'total_cost_usd': cost,
                        'comment': commentCtrl.text,
                        'is_validated': true,
                      })
                      .eq('id', existing['id']);
                }

                if (!mounted) return;

                Navigator.pop(context);
                loadData();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Widget monthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}",
          style: const TextStyle(fontSize: 18),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  selectedMonth =
                      DateTime(selectedMonth.year, selectedMonth.month - 1);
                });
                loadData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  selectedMonth =
                      DateTime(selectedMonth.year, selectedMonth.month + 1);
                });
                loadData();
              },
            ),
          ],
        )
      ],
    );
  }

  Widget table() {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Provider')),
        DataColumn(label: Text('Coût')),
        DataColumn(label: Text('Action')),
      ],
      rows: providers.map((p) {
        final row = data[p];

        return DataRow(cells: [
          DataCell(Text(p)),
          DataCell(Text(money(row?['total_cost_usd']))),
          DataCell(
            ElevatedButton(
              onPressed: () => openEditDialog(p),
              child: Text(row == null ? 'Créer' : 'Modifier'),
            ),
          ),
        ]);
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Providers')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erreur : $error'),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      monthSelector(),
                      const SizedBox(height: 24),
                      table(),
                    ],
                  ),
                ),
    );
  }
}