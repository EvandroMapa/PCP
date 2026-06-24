import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart' show GetOptions;
import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_collection.dart';

class ClienteSupabaseCollection extends ClienteCollection {
  static final ClienteSupabaseCollection _instance =
      ClienteSupabaseCollection._();
  ClienteSupabaseCollection._() : super.base() {
    dataStream = AppStream.seed([]);
  }
  factory ClienteSupabaseCollection() => _instance;

  Timer? _streamDebounce;

  @override
  final String name = 'clientes';
  final String obraTableName = 'obras';

  @override
  List<ClienteModel> get data => dataStream.value;

  bool _isStarted = false;

  @override
  Future<void> fetch({bool lock = true, GetOptions? options}) async {
    _isStarted = false;
    await start(lock: false, options: options);
    _isStarted = true;
  }

  @override
  Future<void> start({bool lock = true, GetOptions? options}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      // Carrega clientes (paginado)
      final List<Map<String, dynamic>> clientesRaw = [];
      int offsetClientes = 0;
      while (true) {
        final chunk = await SupabaseService.client
            .from(name)
            .select()
            .range(offsetClientes, offsetClientes + 999);
        clientesRaw.addAll(List<Map<String, dynamic>>.from(chunk));
        if (chunk.length < 1000) break;
        offsetClientes += 1000;
      }

      // Carrega obras (paginado) para ignorar o limite padrão de 1000 linhas
      final List<Map<String, dynamic>> obrasRaw = [];
      int offsetObras = 0;
      while (true) {
        final chunk = await SupabaseService.client
            .from(obraTableName)
            .select()
            .range(offsetObras, offsetObras + 999);
        obrasRaw.addAll(List<Map<String, dynamic>>.from(chunk));
        if (chunk.length < 1000) break;
        offsetObras += 1000;
      }

      log('[ClienteSupabase.start] clientes=${clientesRaw.length} obras=${obrasRaw.length}');

      // Monta mapa: clienteId (String) → lista de obras
      // Usa toString() para garantir que tipos diferentes (int, String, UUID) não causem mismatch
      final obrasByClienteId = <String, List<Map<String, dynamic>>>{};
      for (final obra in obrasRaw) {
        final clienteId = obra['cliente_id']?.toString();
        if (clienteId != null && clienteId.isNotEmpty) {
          obrasByClienteId.putIfAbsent(clienteId, () => []).add(obra);
        }
      }

      log('[ClienteSupabase.start] obrasByClienteId keys=${obrasByClienteId.keys.toList()}');

      final clientes = clientesRaw.map((c) {
        final clienteId = c['id']?.toString() ?? '';
        final obras = obrasByClienteId[clienteId] ?? [];
        log('[ClienteSupabase.start] cliente=$clienteId (${c['nome']}) obras=${obras.length}');
        return ClienteModel.fromSupabaseMap(c, obras);
      }).toList();

      clientes.sort((a, b) => a.nome.compareTo(b.nome));
      dataStream.add(clientes);
    } catch (e, st) {
      log('Supabase Error (Cliente.start): $e\n$st');
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
        .from(name)
        .stream(primaryKey: ['id']).listen((_) {
          _streamDebounce?.cancel();
          _streamDebounce = Timer(const Duration(milliseconds: 800), () {
            start(lock: false);
          });
        });
  }

  @override
  ClienteModel getById(String id) =>
      data.firstWhere((e) => e.id == id, orElse: () => ClienteModel.empty());

  // ── Cliente CRUD ───────────────────────────────────────────────────────────

  @override
  Future<ClienteModel?> add(ClienteModel model) async {
    final map = model.toSupabaseMap();
    if (model.codigo == 0) {
      map.remove('codigo');
    }
    await SupabaseService.client.from(name).insert(map);
    if (model.obras.isNotEmpty) {
      await SupabaseService.client
          .from(obraTableName)
          .upsert(model.obras.map((e) => e.toSupabaseMap(model.id)).toList());
    }
    // fetch() removido — o Realtime já dispara start() automaticamente
    return model;
  }

  @override
  Future<ClienteModel?> update(ClienteModel model) async {
    await SupabaseService.client
        .from(name)
        .update(model.toSupabaseMap())
        .eq('id', model.id);
    // fetch() removido — o Realtime já dispara start() automaticamente
    return model;
  }

  @override
  Future<void> delete(ClienteModel model) async {
    try {
      await SupabaseService.client
          .from(obraTableName)
          .delete()
          .eq('cliente_id', model.id);
      await SupabaseService.client.from(name).delete().eq('id', model.id);
      // fetch() removido — o Realtime já dispara start() automaticamente
    } catch (e) {
      log('Supabase Error (Cliente.delete): $e');
      rethrow;
    }
  }

  // ── Obras (operações granulares) ───────────────────────────────────────────

  Future<void> addObra(ObraModel obra, String clienteId) async {
    final map = obra.toSupabaseMap(clienteId);
    log('[ClienteSupabase] addObra clienteId=$clienteId map=$map');
    await SupabaseService.client.from(obraTableName).insert(map);
    log('[ClienteSupabase] addObra INSERT OK');
    // fetch() removido — o Realtime já dispara start() automaticamente
  }

  Future<void> updateObra(ObraModel obra, String clienteId) async {
    await SupabaseService.client
        .from(obraTableName)
        .upsert(obra.toSupabaseMap(clienteId));
    // fetch() removido — o Realtime já dispara start() automaticamente
  }

  Future<void> deleteObra(String obraId) async {
    await SupabaseService.client
        .from(obraTableName)
        .delete()
        .eq('id', obraId);
    // fetch() removido — o Realtime já dispara start() automaticamente
  }

  /// Atualiza SOMENTE o endereço da obra (campo JSONB)
  Future<void> updateObraEndereco(
      String obraId, EnderecoModel endereco) async {
    await SupabaseService.client.from(obraTableName).update({
      'endereco': endereco.toMap(),
    }).eq('id', obraId);
    // fetch() removido — o Realtime já dispara start() automaticamente
  }

  /// Atualiza SOMENTE o nome/descrição da obra
  Future<void> updateObraDescricao(String obraId, String descricao) async {
    await SupabaseService.client.from(obraTableName).update({
      'nome': descricao,
    }).eq('id', obraId);
    // fetch() removido — o Realtime já dispara start() automaticamente
  }
}
