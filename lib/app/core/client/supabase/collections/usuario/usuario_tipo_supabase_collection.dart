import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

class UsuarioTipoSupabaseCollection {
  static final UsuarioTipoSupabaseCollection _instance = UsuarioTipoSupabaseCollection._();
  UsuarioTipoSupabaseCollection._();
  factory UsuarioTipoSupabaseCollection() => _instance;

  final String tableName = 'usuario_tipos';

  AppStream<List<UsuarioTipoModel>> dataStream = AppStream.seed([]);
  List<UsuarioTipoModel> get data => dataStream.value;

  bool _isStarted = false;

  Future<void> fetch() async {
    _isStarted = false;
    await start();
    _isStarted = true;
  }

  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(tableName).select().order('nome');
      final tipos = List<Map<String, dynamic>>.from(response)
          .map((e) => UsuarioTipoModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(tipos);
    } catch (e) {
      print('Supabase Error (UsuarioTipo.start): $e');
    }
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .order('nome')
        .listen((List<Map<String, dynamic>> data) {
          final tipos = data.map((e) => UsuarioTipoModel.fromSupabaseMap(e)).toList();
          dataStream.add(tipos);
        });
  }

  UsuarioTipoModel getById(String id) =>
      data.firstWhere((e) => e.id == id, orElse: () => UsuarioTipoModel.empty());

  Future<UsuarioTipoModel?> add(UsuarioTipoModel model) async {
    try {
      await SupabaseService.client.from(tableName).insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (UsuarioTipo.add): $e');
      return null;
    }
  }

  Future<UsuarioTipoModel?> update(UsuarioTipoModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (UsuarioTipo.update): $e');
      return null;
    }
  }

  Future<void> delete(UsuarioTipoModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      print('Supabase Error (UsuarioTipo.delete): $e');
      rethrow;
    }
  }
}
