import 'dart:developer';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_movimentacao_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

class EstoqueMovimentacaoSupabaseCollection {
  static final EstoqueMovimentacaoSupabaseCollection _instance =
      EstoqueMovimentacaoSupabaseCollection._();
  EstoqueMovimentacaoSupabaseCollection._();
  factory EstoqueMovimentacaoSupabaseCollection() => _instance;

  final String name = 'estoque_movimentacao';

  final AppStream<List<EstoqueMovimentacaoModel>> dataStream =
      AppStream<List<EstoqueMovimentacaoModel>>.seed([]);

  List<EstoqueMovimentacaoModel> get data => dataStream.value;

  bool _isStarted = false;

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client
          .from(name)
          .select()
          .order('data_hora', ascending: false);
      final lista = List<Map<String, dynamic>>.from(response)
          .map((e) => EstoqueMovimentacaoModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(lista);
    } catch (e) {
      log('Supabase Error (EstoqueMovimentacao.start): $e');
    }
  }

  Future<void> fetch({bool lock = true}) async {
    _isStarted = false;
    await start(lock: false);
    _isStarted = true;
  }

  Future<void> add(EstoqueMovimentacaoModel model) async {
    try {
      await SupabaseService.client.from(name).insert(model.toSupabaseMap());
      // fetch() removido — o Realtime já dispara atualização automaticamente
    } catch (e) {
      log('Supabase Error (EstoqueMovimentacao.add): $e');
      rethrow;
    }
  }

  bool _isListen = false;
  Future<void> listen() async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .from(name)
        .stream(primaryKey: ['id'])
        .order('data_hora', ascending: false)
        .listen((List<Map<String, dynamic>> data) {
      final lista =
          data.map((e) => EstoqueMovimentacaoModel.fromSupabaseMap(e)).toList();
      dataStream.add(lista);
    });
  }
}
