import 'package:aco_plus/app/modules/elemento/elemento_arquivo_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

class ElementoArquivoSupabaseCollection {
  final String tableName = 'elemento_arquivos';
  final List<ElementoArquivoModel> data = [];
  final AppStream<List<ElementoArquivoModel>> stream = AppStream<List<ElementoArquivoModel>>.seed([]);

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
      data.addAll(response.map((e) => ElementoArquivoModel.fromMap(e)).toList());
      stream.add(data);
    } catch (e) {
      print('Supabase Error (ElementoArquivo.fetch): $e');
    }
  }

  Future<ElementoArquivoModel?> add(ElementoArquivoModel model) async {
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .insert(model.toSupabaseMap())
          .select()
          .single();
      
      final newItem = ElementoArquivoModel.fromMap(response);
      data.add(newItem);
      stream.add(data);
      return newItem;
    } catch (e) {
      print('Supabase Error (ElementoArquivo.add): $e');
      return null;
    }
  }

  Future<void> delete(String id) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', id);
      data.removeWhere((e) => e.id == id);
      stream.add(data);
    } catch (e) {
      print('Supabase Error (ElementoArquivo.delete): $e');
    }
  }

  void listen() {
    SupabaseService.client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> response) {
          data.clear();
          data.addAll(response.map((e) => ElementoArquivoModel.fromMap(e)).toList());
          stream.add(data);
        });
  }
}
