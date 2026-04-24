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

  List<Map<String, dynamic>> snapshots = [];
  List<Map<String, dynamic>> comparison = [];

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
      final snap = await supabase
          .from('provider_usage_snapshots')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      final comp = await supabase
          .from('v_costs_estimated_vs_provider')
          .select();

      setState(() {
        snapshots = List<Map<String, dynamic>>.from(snap);
        comparison = List<Map<String, dynamic>>.from(comp);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void openAddDialog() {
    final providerCtrl = TextEditingController();
    final costCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un snapshot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: providerCtrl,
                decoration: const InputDecoration(labelText: 'Provider (openai, google_vision, railway, supabase)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Coût USD'),
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
                final provider = providerCtrl.text.trim();
                final cost = double.tryParse(costCtrl.text.trim());

                if (provider.isEmpty || cost == null) return;

                await supabase.from('provider_usage_snapshots').insert({
                  'provider': provider,
                  'total_cost_usd': cost,
                });

                if (!mounted) return;

                Navigator.pop(this.context);
                loadData();
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Widget comparisonBlock() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Comparaison estimé vs réel', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            ...comparison.map((row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "${row['source']} → ${money(row['total_cost_usd'])}",
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget snapshotsTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Snapshots providers', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Provider')),
                DataColumn(label: Text('Coût')),
              ],
              rows: snapshots.map((row) {
                return DataRow(cells: [
                  DataCell(Text(row['created_at']?.toString() ?? '—')),
                  DataCell(Text(row['provider']?.toString() ?? '—')),
                  DataCell(Text(money(row['total_cost_usd']))),
                ]);
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
        title: const Text('Providers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadData,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: openAddDialog,
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
                    children: [
                      comparisonBlock(),
                      const SizedBox(height: 24),
                      snapshotsTable(),
                    ],
                  ),
                ),
    );
  }
}