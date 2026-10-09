import 'dart:developer';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseQueryBuilder;

/// Efeito que uma transição de status gera no estoque.
enum EfeitoEstoque { baixa, estorno, nenhum }

/// Posição (OS) lida direto do banco, com o peso já multiplicado pela
/// quantidade do elemento — mesma regra usada no apontamento por OS.
class PosicaoEstoqueRef {
  final String id;
  final PosicaoStatus status;
  final double peso;

  const PosicaoEstoqueRef({
    required this.id,
    required this.status,
    required this.peso,
  });
}

/// Regras de estoque da produção baseadas no estado do BANCO, nunca no cache.
///
/// A baixa só acontece quando ESTE cliente efetivamente move o registro para
/// dentro de `pronto` (e o estorno, quando efetivamente tira de `pronto`).
/// Isso é garantido por updates condicionais (compare-and-set): se outro
/// dispositivo — ou uma tela desatualizada — tentar repetir a transição, o
/// update não afeta nenhuma linha e nenhuma movimentação é gerada.
class EstoqueProducaoService {
  /// Diferenças menores que isso entre a qtde da bitola e a soma das OS são
  /// arredondamento e não geram movimentação de complemento.
  static const double toleranciaComplemento = 0.05;

  static const String _pronto = 'pronto';

  /// Move a posição para [novo] e informa o efeito no estoque.
  ///
  /// `aplicada = false` significa que o banco já estava em outro estado
  /// (ex.: OS já pronta por outro aparelho); nesse caso nada deve ser baixado
  /// e a tela deve ser corrigida com [statusBanco] (null = posição removida).
  static Future<({bool aplicada, EfeitoEstoque efeito, PosicaoStatus? statusBanco})>
      transicionarPosicao(String posicaoId, PosicaoStatus novo) async {
    final payload = {'status': novo.name};

    if (novo == PosicaoStatus.pronto) {
      final rows = await _posicoes()
          .update(payload)
          .eq('id', posicaoId)
          .neq('status', _pronto)
          .select('id');
      if (rows.isNotEmpty) {
        return (aplicada: true, efeito: EfeitoEstoque.baixa, statusBanco: novo);
      }
      return (
        aplicada: false,
        efeito: EfeitoEstoque.nenhum,
        statusBanco: await _statusPosicaoBanco(posicaoId),
      );
    }

    // Saindo de pronto → estorno
    final saiu = await _posicoes()
        .update(payload)
        .eq('id', posicaoId)
        .eq('status', _pronto)
        .select('id');
    if (saiu.isNotEmpty) {
      return (aplicada: true, efeito: EfeitoEstoque.estorno, statusBanco: novo);
    }

    // Não estava pronta → troca simples, sem efeito no estoque.
    // O filtro neq('pronto') impede tirar de pronto sem estorno caso outro
    // aparelho tenha marcado pronto entre as duas escritas.
    final simples = await _posicoes()
        .update(payload)
        .eq('id', posicaoId)
        .neq('status', _pronto)
        .select('id');
    if (simples.isNotEmpty) {
      return (aplicada: true, efeito: EfeitoEstoque.nenhum, statusBanco: novo);
    }
    return (
      aplicada: false,
      efeito: EfeitoEstoque.nenhum,
      statusBanco: await _statusPosicaoBanco(posicaoId),
    );
  }

  /// Reivindica a travessia da fronteira `pronto` do item do pedido
  /// (pedido_bitolas). Retorna [EfeitoEstoque.baixa] apenas para o cliente
  /// que de fato colocou o item em pronto, e [EfeitoEstoque.estorno] apenas
  /// para quem de fato o tirou de pronto. Trocas fora da fronteira não são
  /// gravadas aqui (o chamador grava o status completo depois).
  static Future<EfeitoEstoque> transicionarItem(
    String pedidoBitolaId,
    PedidoBitolaStatus novo,
  ) async {
    if (novo == PedidoBitolaStatus.pronto) {
      final rows = await _itens()
          .update({'status': novo.name})
          .eq('id', pedidoBitolaId)
          .neq('status', _pronto)
          .select('id');
      return rows.isNotEmpty ? EfeitoEstoque.baixa : EfeitoEstoque.nenhum;
    }
    final rows = await _itens()
        .update({'status': novo.name})
        .eq('id', pedidoBitolaId)
        .eq('status', _pronto)
        .select('id');
    return rows.isNotEmpty ? EfeitoEstoque.estorno : EfeitoEstoque.nenhum;
  }

  /// Posições do pedido para a bitola, lidas do banco.
  static Future<List<PosicaoEstoqueRef>> posicoesDoBanco(
    String pedidoId,
    String bitolaId,
  ) async {
    final elementos = await SupabaseService.client
        .from('elementos')
        .select('id, qtde')
        .eq('pedido_id', pedidoId);
    if (elementos.isEmpty) return [];

    final qtdePorElemento = <String, int>{
      for (final e in elementos)
        e['id'].toString(): (e['qtde'] as num?)?.toInt() ?? 1,
    };
    final ids = qtdePorElemento.keys.toList();

    final posicoes = <PosicaoEstoqueRef>[];
    // Lotes para não estourar o tamanho da URL do filtro "in"
    for (var i = 0; i < ids.length; i += 100) {
      final lote = ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100);
      final rows = await SupabaseService.client
          .from('elemento_posicoes')
          .select('id, elemento_id, status, peso_kg')
          .eq('bitola_id', bitolaId)
          .inFilter('elemento_id', lote);
      for (final p in rows) {
        final pesoKg = double.tryParse('${p['peso_kg'] ?? 0}') ?? 0.0;
        posicoes.add(PosicaoEstoqueRef(
          id: p['id'].toString(),
          status: _parsePosicaoStatus(p['status']),
          peso: pesoKg * (qtdePorElemento[p['elemento_id'].toString()] ?? 1),
        ));
      }
    }
    return posicoes;
  }

  /// Quantas OS dos elementos informados estão prontas no BANCO (já baixadas).
  static Future<int> osProntasDosElementos(List<String> elementoIds) async {
    var total = 0;
    for (var i = 0; i < elementoIds.length; i += 100) {
      final lote = elementoIds.sublist(
          i, i + 100 > elementoIds.length ? elementoIds.length : i + 100);
      final rows = await SupabaseService.client
          .from('elemento_posicoes')
          .select('id')
          .eq('status', _pronto)
          .inFilter('elemento_id', lote);
      total += rows.length;
    }
    return total;
  }

  /// Quantas OS do pedido estão prontas no banco.
  static Future<int> osProntasDoPedido(String pedidoId) async {
    final elementos = await SupabaseService.client
        .from('elementos')
        .select('id')
        .eq('pedido_id', pedidoId);
    final ids = elementos.map((e) => e['id'].toString()).toList();
    if (ids.isEmpty) return 0;
    return osProntasDosElementos(ids);
  }

  /// O pedido tem algum item pronto ou alguma OS pronta no banco?
  /// (ou seja, material já baixado do estoque)
  static Future<bool> pedidoTemBaixa(String pedidoId) async {
    final itens = await SupabaseService.client
        .from('pedido_bitolas')
        .select('id')
        .eq('pedido_id', pedidoId)
        .eq('status', _pronto)
        .limit(1);
    if (itens.isNotEmpty) return true;
    return await osProntasDoPedido(pedidoId) > 0;
  }

  /// Itens (pedido_bitolas) que já tiveram baixa: estão prontos no banco ou
  /// têm alguma OS pronta. Usado para impedir que sejam removidos/zerados
  /// sem passar pelo fluxo normal (que faz o estorno).
  static Future<List<String>> itensComBaixa(List<String> pedidoBitolaIds) async {
    final comBaixa = <String>[];
    for (var i = 0; i < pedidoBitolaIds.length; i += 100) {
      final lote = pedidoBitolaIds.sublist(
          i,
          i + 100 > pedidoBitolaIds.length ? pedidoBitolaIds.length : i + 100);
      final rows = await SupabaseService.client
          .from('pedido_bitolas')
          .select('id, pedido_id, bitola_id, status')
          .inFilter('id', lote);
      for (final r in rows) {
        final id = r['id'].toString();
        if (r['status'] == _pronto) {
          comBaixa.add(id);
          continue;
        }
        final posicoes = await posicoesDoBanco(
            r['pedido_id'].toString(), r['bitola_id'].toString());
        if (posicoes.any((p) => p.status == PosicaoStatus.pronto)) {
          comBaixa.add(id);
        }
      }
    }
    return comBaixa;
  }

  /// Parte da qtde do item que NÃO é coberta pelas OS (ou a qtde inteira
  /// quando o pedido não tem OS). É baixada quando o item entra em pronto e
  /// estornada quando sai — em qualquer modo de apontamento.
  static double complementoItem(double qtdeItem, List<PosicaoEstoqueRef> posicoes) {
    if (posicoes.isEmpty) return qtdeItem;
    final totalOs = posicoes.fold(0.0, (s, p) => s + p.peso);
    final diff = qtdeItem - totalOs;
    return diff > toleranciaComplemento ? diff : 0.0;
  }

  static SupabaseQueryBuilder _posicoes() =>
      SupabaseService.client.from('elemento_posicoes');

  static SupabaseQueryBuilder _itens() =>
      SupabaseService.client.from('pedido_bitolas');

  static Future<PosicaoStatus?> _statusPosicaoBanco(String posicaoId) async {
    try {
      final row = await SupabaseService.client
          .from('elemento_posicoes')
          .select('status')
          .eq('id', posicaoId)
          .maybeSingle();
      return row == null ? null : _parsePosicaoStatus(row['status']);
    } catch (e) {
      log('EstoqueProducaoService: erro ao ler status da posição $posicaoId: $e');
      return null;
    }
  }

  static PosicaoStatus _parsePosicaoStatus(dynamic value) =>
      PosicaoStatus.values.firstWhere(
        (e) => e.name == (value ?? 'aguardando'),
        orElse: () => PosicaoStatus.aguardando,
      );
}
