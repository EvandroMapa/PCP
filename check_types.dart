import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://aumfedyfrxuwgkdhwrel.supabase.co',
    'sb_publishable_LTDMyNF9VJdSEpkLDC7t0w_L4HDr7C-',
  );

  try {
    print('--- Pedidos ---');
    final pedidos = await supabase.from('pedidos').select('id, localizador').limit(5);
    for (var p in pedidos) {
      print('Pedido: ${p['id']} (${p['id'].runtimeType}) - Loc: ${p['localizador']}');
    }

    print('\n--- Pedido Produtos ---');
    final produtos = await supabase.from('pedido_produtos').select('pedido_id, quantidade').limit(5);
    for (var prod in produtos) {
      print('Produto vinculando a Pedido: ${prod['pedido_id']} (${prod['pedido_id'].runtimeType}) - Qtd: ${prod['quantidade']}');
    }
  } catch (e) {
    print('Erro: $e');
  }
}
