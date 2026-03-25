import 'package:aco_plus/app/core/models/service_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sf;

class SupabaseService implements Service {
  @override
  Future<void> initialize() async {
    const url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://aumfedyfrxuwgkdhwrel.supabase.co');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8');

    try {
      await sf.Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      // Accessing our custom collection wrapper
      await AppSupabaseClient.init();
      print('Supabase: Initialized successfully.');
    } catch (e) {
      print('Supabase: Error during initialization: $e');
    }
  }

  // Returns the official SDK SupabaseClient from supabase_flutter
  static sf.SupabaseClient get client => sf.Supabase.instance.client;
}
