import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://aumfedyfrxuwgkdhwrel.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
  );

  final clientesRaw = await supabase.from('clientes').select();
  final obrasRaw = await supabase.from('obras').select();

  final obrasByClienteId = <String, List<Map<String, dynamic>>>{};
  for (final obra in obrasRaw) {
    final clienteId = obra['cliente_id']?.toString() ?? '';
    obrasByClienteId.putIfAbsent(clienteId, () => []).add(obra);
  }

  print('Buscando cliente vWW...');
  final evandro = clientesRaw.firstWhere((c) => c['id'] == 'vWWcR7lSm8dYebENChgqOzUE8', orElse: () => {});
  print('Cliente encontrado: $evandro');

  print('Todas as obras encontradas para esse cliente_id na tabela OBRAS:');
  for (final o in obrasRaw) {
    if (o['cliente_id'] == 'vWWcR7lSm8dYebENChgqOzUE8') {
      print(o);
    }
  }

  print('Tamanho total da tabela obras: ${obrasRaw.length}');
  print('Chaves diferentes em obras: ${obrasByClienteId.keys.take(10).toList()}...');
  
  // Imprimir se a chave vWWcR7lSm8dYebENChgqOzUE8 está presente
  print('A chave vWWcR7lSm8dYebENChgqOzUE8 esta presente? ${obrasByClienteId.containsKey('vWWcR7lSm8dYebENChgqOzUE8')}');
}
