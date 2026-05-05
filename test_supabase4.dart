import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://aumfedyfrxuwgkdhwrel.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
  );

  final List<Map<String, dynamic>> obrasRaw = [];
  int offset = 0;
  while (true) {
    print('Buscando offset $offset...');
    final chunk = await supabase.from('obras').select().range(offset, offset + 999);
    obrasRaw.addAll(List<Map<String, dynamic>>.from(chunk));
    if (chunk.length < 1000) break;
    offset += 1000;
  }
  print('Total de obras encontradas: ${obrasRaw.length}');
  
  final evandroObras = obrasRaw.where((o) => o['cliente_id'] == 'vWWcR7lSm8dYebENChgqOzUE8').toList();
  print('Obras do EVANDRO: ${evandroObras.length}');
}
