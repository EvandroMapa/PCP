import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://aumfedyfrxuwgkdhwrel.supabase.co',
    'sb_publishable_LTDMyNF9VJdSEpkLDC7t0w_L4HDr7C-',
  );

  final table = 'pedido_produtos';
  
  print('--- Testando $table ---');
  try {
    final selectRes = await supabase.from(table).select().limit(1);
    print('Select em $table funcionou! Registros: ${selectRes.length}');
    
    final payload = {
      'id_id': 'DEBUG_${DateTime.now().millisecondsSinceEpoch}',
      'pedido_id': 'ZQU6nECZwZfnUJW6zsWNHGPJp',
      'cliente_id': 'CO2xa7TCgphsz6FTOZ00eIBGP',
      'obra_id': 'ALfNMGUn8rCzDaGawMHno5HsE',
      'quantidade': 1.0,
      'produto_raw': {'nome': 'Debug Item'},
    };
    
    print('Tentando insert em $table...');
    final insertRes = await supabase.from(table).insert(payload).select();
    print('Insert em $table funcionou! Resposta: $insertRes');
    
  } catch (e) {
    print('ERRO EM $table: $e');
  }
}
