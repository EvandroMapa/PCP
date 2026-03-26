import 'package:aco_plus/app/core/models/service_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sf;

class SupabaseService implements Service {
  // Chaves hardcoded como fallback para modo debug
  static const String _defaultUrl = 'https://aumfedyfrxuwgkdhwrel.supabase.co';
  static const String _defaultAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8';

  @override
  Future<void> initialize() async {
    // String.fromEnvironment só funciona em release builds.
    // Em debug, usamos o fallback diretamente.
    const envUrl = String.fromEnvironment('SUPABASE_URL');
    const envKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    
    final url = envUrl.isNotEmpty ? envUrl : _defaultUrl;
    final anonKey = envKey.isNotEmpty ? envKey : _defaultAnonKey;

    try {
      await sf.Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      // Accessing our custom collection wrapper
      await AppSupabaseClient.init();
      print('Supabase: Initialized successfully with URL: $url');
    } catch (e) {
      print('Supabase: Error during initialization: $e');
    }
  }

  // Returns the official SDK SupabaseClient from supabase_flutter
  static sf.SupabaseClient get client => sf.Supabase.instance.client;
}
