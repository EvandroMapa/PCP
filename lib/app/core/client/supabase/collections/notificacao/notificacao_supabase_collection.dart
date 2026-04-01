import 'package:aco_plus/app/core/client/firestore/collections/notificacao/notificacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/notificacao/notificacao_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacaoSupabaseCollection extends NotificacaoCollection {
  static final NotificacaoSupabaseCollection _instance =
      NotificacaoSupabaseCollection._();
  NotificacaoSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory NotificacaoSupabaseCollection() => _instance;

  @override
  final String tableName = 'notificacoes';

  @override
  List<NotificacaoModel> get data =>
      dataStream.value.where((e) => e.userId == usuario.id).toList();

  bool _isStarted = false;

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client
          .from(tableName)
          .select()
          .order('created_at', ascending: true);
      final notificacoes = List<Map<String, dynamic>>.from(response)
          .map((e) => NotificacaoModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(notificacoes);
    } catch (e) {
      print('Supabase Error (Notificacao.start): $e');
    }
  }

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<NotificacaoModel?> add(NotificacaoModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .insert(model.toSupabaseMap());
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Notificacao.add): $e');
      return null;
    }
  }

  @override
  Future<NotificacaoModel?> update(NotificacaoModel model) async {
    try {
      await SupabaseService.client
          .from(tableName)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      await fetch();
      return model;
    } catch (e) {
      print('Supabase Error (Notificacao.update): $e');
      return null;
    }
  }

  @override
  Future<void> delete(NotificacaoModel model) async {
    try {
      await SupabaseService.client.from(tableName).delete().eq('id', model.id);
      await fetch();
    } catch (e) {
      print('Supabase Error (Notificacao.delete): $e');
    }
  }

  bool _isListen = false;
  @override
  Future<void> listen({
    Object? field,
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) async {
    if (_isListen) return;
    _isListen = true;
    SupabaseService.client
        .from(tableName)
        .stream(primaryKey: ['id'])
        .listen((List<Map<String, dynamic>> data) {
      final notificacoes =
          data.map((e) => NotificacaoModel.fromSupabaseMap(e)).toList();
      notificacoes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      dataStream.add(notificacoes);
    });
  }
}
