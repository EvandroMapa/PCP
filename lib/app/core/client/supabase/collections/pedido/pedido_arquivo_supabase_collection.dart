import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_arquivo_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

class PedidoArquivoSupabaseCollection {
  final String tableName = 'pedido_arquivos';
  final List<PedidoArquivoModel> data = [];
  final AppStream<List<PedidoArquivoModel>> stream = AppStream<List<PedidoArquivoModel>>.seed([]);

  Future<void> start() async {
    await fetch();
  }

  Future<void> fetch() async {
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .select()
          .order('criado_em', ascending: false);
      
      data.clear();
      data.addAll(response.map((e) => PedidoArquivoModel.fromMap(e)).toList());
      stream.add(data);
    } catch (e) {
      print('Supabase Error (PedidoArquivo.fetch): $e');
    }
  }

  Future<PedidoArquivoModel?> add(PedidoArquivoModel model) async {
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .insert(model.toSupabaseMap())
          .select()
          .single();
      
      final newItem = PedidoArquivoModel.fromMap(response);
      data.add(newItem);
      stream.add(data);
      return newItem;
    } catch (e) {
      print('Supabase Error (PedidoArquivo.add): $e');
      return null;
    }
  }

  Future<void> delete(String id) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', id);
      data.removeWhere((e) => e.id == id);
      stream.add(data);
    } catch (e) {
      print('Supabase Error (PedidoArquivo.delete): $e');
    }
  }

  void listen() {
    SupabaseService.client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> response) {
          data.clear();
          data.addAll(response.map((e) => PedidoArquivoModel.fromMap(e)).toList());
          stream.add(data);
        });
  }
}
