import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_v2/admin_login_screen.dart';
import 'admin_v2/admin_dashboard_screen.dart';
import 'admin_v2/admin_costs_screen.dart';
import 'admin_v2/admin_documents_screen_v2.dart';
import 'admin_v2/admin_jobs_screen.dart';
import 'admin_v2/admin_providers_screen.dart';
import 'admin_v2/admin_voice_rules_screen_v2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sxculvrepieflqqjtxfi.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN4Y3VsdnJlcGllZmxxcWp0eGZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTY5NzEsImV4cCI6MjA4NTE5Mjk3MX0.fMZe5pwl0zUFJctUnHeP1pFTT9rc4WrY4K7X8WNBr88',
  );

  runApp(const MyApp());
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (session == null) {
          return const AdminLoginScreen();
        }

        return const _AdminCheck();
      },
    );
  }
}

class _AdminCheck extends StatefulWidget {
  const _AdminCheck();

  @override
  State<_AdminCheck> createState() => _AdminCheckState();
}

class _AdminCheckState extends State<_AdminCheck> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  Future<void> checkAdmin() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        isLoading = false;
        isAdmin = false;
      });
      return;
    }

    final resp = await supabase
        .from('profiles')
        .select('is_admin')
        .eq('id', user.id)
        .maybeSingle();

    if (!mounted) return;

    setState(() {
      isAdmin = resp?['is_admin'] == true;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!isAdmin) {
      return const AdminLoginScreen();
    }

    return const AdminDashboardScreen();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'findAll Admin',
      home: const AuthGate(),
      routes: {
        '/login': (context) => const AdminLoginScreen(),
        '/admin': (context) => const AdminDashboardScreen(),
        '/admin-costs': (context) => const AdminCostsScreen(),
        '/admin-docs': (context) => const AdminDocumentsScreenV2(),
        '/admin-jobs': (context) => const AdminJobsScreen(),
        '/admin-providers': (context) => const AdminProvidersScreen(),
        '/admin-voice': (context) => const AdminVoiceRulesScreenV2(),
      },
    );
  }
}