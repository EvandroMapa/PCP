import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://aumfedyfrxuwgkdhwrel.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
  );

  try {
    print('Testando join nativo...');
    final data = await supabase.from('clientes').select('id, obras(id, nome)').eq('id', 'vWWcR7lSm8dYebENChgqOzUE8');
    print(data);
  } catch (e) {
    print('Erro no join: $e');
  }
}
