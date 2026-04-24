import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {

  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String? error;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final response = await supabase
          .from('v_cost_events_global_summary')
          .select()
          .single();

      setState(() {
        data = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Widget _menuButton(BuildContext context, String label, String route) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pushNamed(context, route);
      },
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('findAll Admin v2'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Text("Erreur: $error")
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Admin",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        //_menuButton(context, "Dashboard", "/admin"),
                        _menuButton(context, "Coûts", "/admin-costs"),
                        _menuButton(context, "Documents", "/admin-docs"),
                        _menuButton(context, "Jobs", "/admin-jobs"),
                        _menuButton(context, "Providers", "/admin-providers"),
                        _menuButton(context, "Voice Rules", "/admin-voice"),
                      ],
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      "Résumé",
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),

                    Text("Total events: ${data?['total_events']}"),
                    Text("Success: ${data?['success_events']}"),
                    Text("Failed: ${data?['failed_events']}"),

                    const SizedBox(height: 16),

                    Text("Total cost: ${data?['total_cost_usd']?.toStringAsFixed(4)} \$"),
                    Text("OCR cost: ${data?['total_ocr_cost_usd']?.toStringAsFixed(4)} \$"),
                    Text("LLM cost: ${data?['total_llm_cost_usd']?.toStringAsFixed(4)} \$"),
                  ],
                ),
      )
    );
  }
}