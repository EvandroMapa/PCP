import 'dart:developer';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

class PedidoCompraSupabaseCollection {
  static final PedidoCompraSupabaseCollection _instance =
      PedidoCompraSupabaseCollection._();
  PedidoCompraSupabaseCollection._();
  factory PedidoCompraSupabaseCollection() => _instance;

  final String name = 'pedidos_compra';

  final AppStream<List<PedidoCompraModel>> dataStream =
      AppStream<List<PedidoCompraModel>>.seed([]);

  List<PedidoCompraModel> get data => dataStream.value;

  List<PedidoCompraModel> get pendentes =>
      data.where((e) => e.isPendente).toList();

  List<PedidoCompraModel> get confirmados =>
      data.where((e) => e.isConfirmado).toList();

  /// Ativos = pendente + confirmado (ainda não chegaram ao estoque)
  List<PedidoCompraModel> get ativos =>
      data.where((e) => e.isAtivo).toList();

  List<PedidoCompraModel> get efetivados =>
      data.where((e) => e.isConvertido).toList();

  /// Retorna ativos agrupados por grupoId — mais recente primeiro
  Map<String, List<PedidoCompraModel>> get ativosAgrupados {
    final Map<String, List<PedidoCompraModel>> grupos = {};
    for (final item in ativos) {
      grupos.putIfAbsent(item.grupoId, () => []).add(item);
    }
    // Ordena grupos pelo createdAt do primeiro item (mais recente primeiro)
    final entries = grupos.entries.toList()
      ..sort((a, b) =>
          b.value.first.createdAt.compareTo(a.value.first.createdAt));
    return Map.fromEntries(entries);
  }

  /// Retorna efetivados agrupados por grupoId — mais recente primeiro
  Map<String, List<PedidoCompraModel>> get efetivadosAgrupados {
    final Map<String, List<PedidoCompraModel>> grupos = {};
    for (final item in efetivados) {
      grupos.putIfAbsent(item.grupoId, () => []).add(item);
    }
    final entries = grupos.entries.toList()
      ..sort((a, b) =>
          b.value.first.createdAt.compareTo(a.value.first.createdAt));
    return Map.fromEntries(entries);
  }

  /// Ativos (pendente + confirmado) por produto — usado em contextos gerais
  List<PedidoCompraModel> getPendentesByProdutoId(String produtoId) =>
      data.where((e) => e.isAtivo && e.produtoId == produtoId).toList();

  double getTotalPendenteByProdutoId(String produtoId) =>
      getPendentesByProdutoId(produtoId)
          .fold(0.0, (sum, e) => sum + e.quantidade);

  /// Apenas CONFIRMADOS por produto — usado nos painéis de estoque e simulador de compra
  List<PedidoCompraModel> getConfirmadosByProdutoId(String produtoId) =>
      data.where((e) => e.isConfirmado && e.produtoId == produtoId).toList();

  double getTotalConfirmadoByProdutoId(String produtoId) =>
      getConfirmadosByProdutoId(produtoId)
          .fold(0.0, (sum, e) => sum + e.quantidade);

  bool _isStarted = false;

  Future<void> start({bool lock = true}) async {
    if (_isStarted && lock) return;
    _isStarted = true;
    try {
      final response = await SupabaseService.client
          .from(name)
          .select()
          .order('created_at', ascending: false);
      final lista = List<Map<String, dynamic>>.from(response)
          .map((e) => PedidoCompraModel.fromSupabaseMap(e))
          .toList();
      dataStream.add(lista);
    } catch (e) {
      log('Supabase Error (PedidoCompra.start): $e');
    }
  }

  Future<void> fetch() async {
    _isStarted = false;
    await start(lock: false);
    _isStarted = true;
  }

  Future<void> add(PedidoCompraModel model) async {
    try {
      await SupabaseService.client.from(name).insert(model.toSupabaseMap());
      // fetch() removido — o Realtime já dispara atualização automaticamente
    } catch (e) {
      log('Supabase Error (PedidoCompra.add): $e');
      rethrow;
    }
  }

  Future<void> update(PedidoCompraModel model) async {
    try {
      await SupabaseService.client
          .from(name)
          .update(model.toSupabaseMap())
          .eq('id', model.id);
      // fetch() removido — o Realtime já dispara atualização automaticamente
    } catch (e) {
      log('Supabase Error (PedidoCompra.update): $e');
      rethrow;
    }
  }

  Future<void> delete(PedidoCompraModel model) async {
    try {
      await SupabaseService.client.from(name).delete().eq('id', model.id);
      // fetch() removido — o Realtime já dispara atualização automaticamente
    } catch (e) {
      log('Supabase Error (PedidoCompra.delete): $e');
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
      final lista = data
          .map((e) => PedidoCompraModel.fromSupabaseMap(e))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      dataStream.add(lista);
    });
  }
}
