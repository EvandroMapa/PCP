import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://aumfedyfrxuwgkdhwrel.supabase.co',
    'sb_publishable_LTDMyNF9VJdSEpkLDC7t0w_L4HDr7C-',
  );

  final pedidoId = 'ZQU6nECZwZfnUJW6zsWNHGPJp';
  
  print('--- Teste de Inserção de Produto ---');
  final payload = {
    'id': 'TEST_PROD_1',
    'id_id': 'TEST_PROD_1',
    'pedido_id': pedidoId,
    'cliente_id': 'CO2xa7TCgphsz6FTOZ00eIBGP',
    'obra_id': 'ALfNMGUn8rCzDaGawMHno5HsE',
    'quantidade': 50.0,
    'produto_raw': {'nome': 'Test Item'},
    'statusess_raw': [],
  };

  try {
    print('Tentando inserir no pedido $pedidoId...');
    final res = await supabase.from('pedido_produtos').insert(payload);
    print('Sucesso na inserção! Resposta: $res');
  } catch (e) {
    print('FALHA NA INSERÇÃO: $e');
  }
}
