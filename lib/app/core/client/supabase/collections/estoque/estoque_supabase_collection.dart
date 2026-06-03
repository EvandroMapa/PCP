import 'dart:developer';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

class EstoqueSupabaseCollection {
  static final EstoqueSupabaseCollection _instance =
      EstoqueSupabaseCollection._();
  EstoqueSupabaseCollection._();
  factory EstoqueSupabaseCollection() => _instance;

  final String name = 'estoque';

  final AppStream<List<EstoqueModel>> dataStream =
      AppStream<List<EstoqueModel>>.seed([]);

  List<EstoqueModel> get data => dataStream.value;

  EstoqueModel? getByProdutoId(String produtoId) {
    try {
      return data.firstWhere((e) => e.produtoId == produtoId);
    } catch (_) {
      return null;
    }
  }

  bool _isStarted = false;

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client.from(name).select();
      final lista = List<Map<String, dynamic>>.from(response)
          .map((e) => EstoqueModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(lista);
    } catch (e) {
      log('Supabase Error (Estoque.start): $e');
    }
  }

  Future<void> fetch({bool lock = true}) async {
    _isStarted = false;
    await start(lock: false);
    _isStarted = true;
  }

  Future<void> upsert(EstoqueModel model) async {
    try {
      await SupabaseService.client.from(name).upsert(
            model.toSupabaseMap(),
            onConflict: 'bitola_id',
          );
      await fetch();
    } catch (e) {
      log('Supabase Error (Estoque.upsert): $e');
      rethrow;
    }
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .from(name)
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      final lista =
          data.map((e) => EstoqueModel.fromSupabaseMap(e)).toList();
      dataStream.add(lista);
    });
  }
}
