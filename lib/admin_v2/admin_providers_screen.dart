import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_layout.dart';

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
  Map<String, dynamic>? estimatedRow;
  Map<String, dynamic>? providerRow;

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

  double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> asMapList(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  String monthKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-01";
  }

  String dateKey(DateTime d) {
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  }

  DateTime monthEnd(DateTime d) {
    return DateTime(d.year, d.month + 1, 0);
  }

  static bool isDebugProviders = false;

  void log(String label, dynamic value) {
    if (!isDebugProviders) return;
    debugPrint('[findAll][providers][$label] ${value.toString()}');
  }

  Future<double> fetchEurUsdRate(DateTime date) async {
    final fxDate = dateKey(date);

    final uri = Uri.parse(
      'https://api.frankfurter.dev/v2/rates?date=$fxDate&base=EUR&quotes=USD',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    // 👉 CAS 1 : LIST (ton cas actuel)
    if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;

      if (first is Map && first['rate'] is num) {
        return (first['rate'] as num).toDouble();
      }
    }

    // 👉 CAS 2 : MAP (fallback possible API)
    if (decoded is Map) {
      final rates = decoded['rates'];

      if (rates is Map && rates['USD'] is num) {
        return (rates['USD'] as num).toDouble();
      }
    }

    throw Exception('Format FX inattendu : $decoded');
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

      final rows = asMapList(res);

      final comp = await supabase
          .from('v_costs_estimated_vs_provider_monthly')
          .select()
          .eq('period_month', month);

      final compRows = asMapList(comp);

      final estimated = compRows.firstWhere(
        (row) => row['source'] == 'estimated',
        orElse: () => {},
      );

      final provider = compRows.firstWhere(
        (row) => row['source'] == 'provider',
        orElse: () => {},
      );

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
        estimatedRow = estimated.isEmpty ? null : estimated;
        providerRow = provider.isEmpty ? null : provider;
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
    final existingRaw = data[provider];
    final existing = existingRaw != null
        ? Map<String, dynamic>.from(existingRaw)
        : null;

    final costCtrl = TextEditingController(
      text: existing?['original_cost']?.toString() ??
          existing?['total_cost_usd']?.toString() ??
          '',
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
                decoration: const InputDecoration(labelText: 'Coût réel en €'),
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
              try {
                log('SAVE CLICK', provider);
                final costEur = double.tryParse(
                  costCtrl.text.trim().replaceAll(',', '.'),
                );

                if (costEur == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coût invalide')),
                  );
                  return;
                }

                final month = monthKey(selectedMonth);
                final fxDate = monthEnd(selectedMonth);
                final fxRate = await fetchEurUsdRate(fxDate);
                final costUsd = costEur * fxRate;

                if (existing == null) {
                  await supabase.from('provider_usage_snapshots').insert({
                    'provider': provider,
                    'total_cost_usd': costUsd,
                    'original_cost': costEur,
                    'original_currency': 'EUR',
                    'fx_rate_eur_usd': fxRate,
                    'fx_rate_date': dateKey(fxDate),
                    'period_start': month,
                    'period_end': dateKey(fxDate),
                    'period_month': month,
                    'is_validated': true,
                    'source': 'admin_manual',
                    'comment': commentCtrl.text,
                  });
                } else {
                  log('UPDATE EXISTING ID TYPE', existing['id']?.runtimeType);
                  log('UPDATE EXISTING ID', existing['id']);
                  if (existing['id'] == null) {
                    throw Exception('ID manquant pour update');
                  }

                  await supabase
                      .from('provider_usage_snapshots')
                      .update({
                        'total_cost_usd': costUsd,
                        'original_cost': costEur,
                        'original_currency': 'EUR',
                        'fx_rate_eur_usd': fxRate,
                        'fx_rate_date': dateKey(fxDate),
                        'comment': commentCtrl.text,
                        'is_validated': true,
                      })
                      .eq('id', existing['id'].toString());
                }

                if (!mounted) return;

                Navigator.pop(context);
                await loadData();

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coût provider enregistré')),
                );
              } catch (e, stack) {
                log('SAVE ERROR', e);
                log('SAVE STACK', stack);
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur sauvegarde : $e')),
                );
              }
            },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
  }

  Widget comparisonBlock() {
    final estimated = toDouble(estimatedRow?['total_cost_usd']);
    final real = toDouble(providerRow?['total_cost_usd']);

    final diffUsd = real - estimated;
    final diffRate = estimated > 0 ? (diffUsd / estimated) * 100 : 0;

    final isOverCost = diffUsd > 0;

    return Card(
      color: isOverCost ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparaison estimé vs réel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('Mois : ${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}'),
            const SizedBox(height: 8),
            Text('Estimé : ${money(estimated)}'),
            Text('Réel : ${money(real)}'),
            const SizedBox(height: 8),
            Text(
              'Écart : ${money(diffUsd)} (${diffRate.toStringAsFixed(1)} %)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOverCost ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
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
    return AdminLayout(
      title: 'Providers',
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
                      monthSelector(),
                      const SizedBox(height: 24),
                      comparisonBlock(),
                      const SizedBox(height: 24),
                      table(),
                    ],
                  ),
                ),
    );
  }
}