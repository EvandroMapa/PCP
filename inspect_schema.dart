import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabase = SupabaseClient(
    'https://aumfedyfrxuwgkdhwrel.supabase.co',
    'sb_publishable_LTDMyNF9VJdSEpkLDC7t0w_L4HDr7C-',
  );

  try {
    print('--- Inspecionando pcp_supabase_tables.sql vs Realidade ---');
    
    // Tentar pegar informações das colunas via SQL (se tiver permissão) ou via select
    final tables = ['pedidos', 'pedido_produtos', 'pedido_status_history'];
    
    for (var table in tables) {
      print('\nInspecionando tabela: $table');
      try {
        final res = await supabase.from(table).select().limit(1);
        if (res.isNotEmpty) {
          print('Exemplo de registro em $table:');
          res.first.forEach((key, value) {
            print('  - $key: $value (${value.runtimeType})');
          });
        } else {
          print('Tabela $table está vazia.');
        }
      } catch (e) {
        print('Erro ao ler $table: $e');
      }
    }
  } catch (e) {
    print('Erro Geral: $e');
  }
}
