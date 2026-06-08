import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/modulo_importacao/spe/spe_supabase_client.dart';
import 'package:collection/collection.dart';

/// Resultado da extração de dados do pedido técnico SPE.
class SpeExtracao {
  /// Produtos (bitolas) agrupados: cada item = 1 bitola com peso total
  final List<SpeBitolaExtraida> bitolas;

  /// Elementos com suas posições
  final List<SpeElementoExtraido> elementos;

  /// Bitolas não encontradas no PCP
  final List<String> bitolasSemMatch;

  SpeExtracao({
    required this.bitolas,
    required this.elementos,
    required this.bitolasSemMatch,
  });
}

class SpeBitolaExtraida {
  final String bitolaNome; // ex: "CA-50 8.0mm"
  final double pesoTotalKg;
  final BitolaModel? produtoPcp; // null se não encontrou match

  SpeBitolaExtraida({
    required this.bitolaNome,
    required this.pesoTotalKg,
    this.produtoPcp,
  });
}

class SpeElementoExtraido {
  final String nome; // ex: "V1"
  final int qtde;
  final List<SpePosicaoExtraida> posicoes;

  double get pesoTotal =>
      posicoes.fold(0.0, (s, p) => s + p.pesoKg) * qtde;

  SpeElementoExtraido({
    required this.nome,
    required this.qtde,
    required this.posicoes,
  });
}

class SpePosicaoExtraida {
  final String nome; // ex: "Pos 1"
  final String bitolaNome;
  final double pesoKg;
  final int qtde;
  final double comprCorte;
  final BitolaModel? produtoPcp;

  SpePosicaoExtraida({
    required this.nome,
    required this.bitolaNome,
    required this.pesoKg,
    required this.qtde,
    required this.comprCorte,
    this.produtoPcp,
  });
}

/// Serviço de importação SPE → PCP.
/// Totalmente isolável — para remover, deletar este arquivo e suas referências.
class SpeImportacaoService {
  final SpeSupabaseClient _speClient = SpeSupabaseClient();

  /// Extrai e agrupa os dados de um pedido técnico SPE para preview.
  /// Não salva nada — apenas prepara os dados para conferência.
  Future<SpeExtracao> extrairDados(Map<String, dynamic> pedidoTecnico) async {
    final elementos =
        List<Map<String, dynamic>>.from(pedidoTecnico['elementos'] ?? []);
    if (elementos.isEmpty) {
      return SpeExtracao(bitolas: [], elementos: [], bitolasSemMatch: []);
    }

    // Buscar detalhamento para obter posições com bitolas
    final detalhamentoId = pedidoTecnico['detalhamento_id'] as String? ?? '';

    // Buscar elementos do detalhamento para obter os IDs reais
    final elementosDetalhamento =
        await _speClient.buscarElementosDoDetalhamento(detalhamentoId);

    // Mapear elementoId do pedido técnico → elemento do detalhamento
    final elementoIds =
        elementosDetalhamento.map((e) => e['id'].toString()).toList();

    // Buscar posições de todos os elementos do detalhamento
    final posicoesSpe = await _speClient.buscarPosicoesPorElementoIds(elementoIds);

    // Buscar bitolas do SPE para ter massaFinal
    final bitolasSpe = await _speClient.buscarBitolas();
    final bitolasPorId = <String, Map<String, dynamic>>{};
    for (final b in bitolasSpe) {
      bitolasPorId[b['id'].toString()] = b;
    }

    // Produtos do PCP para match
    final produtosPcp = FirestoreClient.bitolas.data;

    // ── Processar cada elemento do pedido técnico ──────────────────────────
    final elementosExtraidos = <SpeElementoExtraido>[];
    final bitolaAcumulado = <String, double>{}; // bitolaNome → peso total
    final bitolaMatch = <String, BitolaModel?>{}; // cache de match

    for (final elemPt in elementos) {
      final elementoId = elemPt['elemento_id']?.toString() ?? '';
      final elementoNome = elemPt['elemento_nome']?.toString() ?? '';
      final qtdeSolicitada =
          int.tryParse(elemPt['quantidade_solicitada']?.toString() ?? '1') ?? 1;
      final qtdeTotal =
          int.tryParse(elemPt['elemento_quantidade']?.toString() ?? '1') ?? 1;
      // peso_total do SPE — valor correto calculado pelo sistema de origem
      final pesoTotalSpe =
          double.tryParse(elemPt['peso_total']?.toString() ?? '0') ?? 0.0;

      // Filtrar posições deste elemento no detalhamento
      final posicoesDoElemento =
          posicoesSpe.where((p) => p['elemento_id'] == elementoId).toList();

      // ── 1ª passagem: calcular pesos brutos de cada posição ──────────────
      final dadosPosicoes = <Map<String, dynamic>>[];
      double somaPesoBruto = 0;

      for (final pos in posicoesDoElemento) {
        final bitolaId = pos['bitola_id']?.toString() ?? '';
        final bitolaNome = pos['bitola_nome']?.toString() ?? '';
        final qtdePos = int.tryParse(pos['qtde']?.toString() ?? '1') ?? 1;
        final comprCorte = double.tryParse(
                pos['comprimento_de_corte']?.toString() ?? '0') ??
            0.0;

        final bitolaData = bitolasPorId[bitolaId];
        final massaFinal = bitolaData != null
            ? (double.tryParse(
                    (bitolaData['massa_final'] ?? '0').toString()) ??
                0.0)
            : 0.0;

        // Peso bruto proporcional (pode divergir do SPE, serve apenas
        // para distribuir o peso_total correto entre as posições)
        final pesoRaw = qtdePos * (comprCorte / 100) * massaFinal;
        somaPesoBruto += pesoRaw;

        // Match com BitolaModel do PCP
        if (!bitolaMatch.containsKey(bitolaNome)) {
          bitolaMatch[bitolaNome] = _encontrarProdutoPcp(
            produtosPcp,
            bitolaNome,
            bitolaData,
          );
        }

        dadosPosicoes.add({
          'pos': pos,
          'bitolaId': bitolaId,
          'bitolaNome': bitolaNome,
          'qtdePos': qtdePos,
          'comprCorte': comprCorte,
          'pesoRaw': pesoRaw,
        });
      }

      // ── Fator de correção usando peso_total do SPE ──────────────────────
      // peso_total do SPE é para a quantidade_solicitada; obtemos o unitário
      final pesoUnitarioSpe =
          qtdeSolicitada > 0 ? pesoTotalSpe / qtdeSolicitada : pesoTotalSpe;
      final fatorCorrecao =
          (somaPesoBruto > 0 && pesoUnitarioSpe > 0)
              ? pesoUnitarioSpe / somaPesoBruto
              : 1.0;

      // ── 2ª passagem: criar posições com peso corrigido ──────────────────
      final posicoesExtraidas = <SpePosicaoExtraida>[];
      int posCounter = 1;

      for (final dados in dadosPosicoes) {
        final pesoPos = (dados['pesoRaw'] as double) * fatorCorrecao;
        final bitolaNome = dados['bitolaNome'] as String;

        posicoesExtraidas.add(SpePosicaoExtraida(
          nome: 'Pos ${(dados['pos'] as Map)['posicao'] ?? posCounter}',
          bitolaNome: bitolaNome,
          pesoKg: pesoPos,
          qtde: dados['qtdePos'] as int,
          comprCorte: dados['comprCorte'] as double,
          produtoPcp: bitolaMatch[bitolaNome],
        ));

        // Acumular peso por bitola (proporcional à qtdeSolicitada)
        final pesoProporcionado =
            qtdeTotal > 0 ? (pesoPos / qtdeTotal) * qtdeSolicitada : pesoPos;
        bitolaAcumulado[bitolaNome] =
            (bitolaAcumulado[bitolaNome] ?? 0) + pesoProporcionado;

        posCounter++;
      }

      elementosExtraidos.add(SpeElementoExtraido(
        nome: elementoNome,
        qtde: qtdeSolicitada,
        posicoes: posicoesExtraidas,
      ));
    }

    // ── Montar lista de bitolas agrupadas ──────────────────────────────────
    final bitolasExtraidas = bitolaAcumulado.entries.map((e) {
      return SpeBitolaExtraida(
        bitolaNome: e.key,
        pesoTotalKg: double.parse(e.value.toStringAsFixed(3)),
        produtoPcp: bitolaMatch[e.key],
      );
    }).toList();

    final bitolasSemMatch = bitolasExtraidas
        .where((b) => b.produtoPcp == null)
        .map((b) => b.bitolaNome)
        .toList();

    return SpeExtracao(
      bitolas: bitolasExtraidas,
      elementos: elementosExtraidos,
      bitolasSemMatch: bitolasSemMatch,
    );
  }

  /// Importa os dados extraídos para dentro de um pedido existente no PCP.
  /// [modo]: 'substituir' limpa os existentes, 'acrescentar' adiciona.
  Future<void> importarParaPedido({
    required PedidoModel pedido,
    required SpeExtracao extracao,
    required String modo, // 'substituir' | 'acrescentar'
  }) async {
    try {
      // ── 1. Tratar produtos (bitolas) ──────────────────────────────────────
      if (modo == 'substituir') {
        // Remover produtos existentes do pedido
        await SupabaseService.client
            .from('pedido_bitolas')
            .delete()
            .eq('pedido_id', pedido.id);
      }

      // Inserir novos produtos
      for (final bitola in extracao.bitolas) {
        if (bitola.produtoPcp == null) continue; // pular bitolas sem match

        final produtoId = HashService.get;
        await SupabaseService.client.from('pedido_bitolas').insert({
          'id': produtoId,
          'id_id': produtoId,
          'pedido_id': pedido.id,
          'bitola_id': bitola.produtoPcp!.id,
          'bitola_raw': bitola.produtoPcp!.toMap(),
          'qtde': bitola.pesoTotalKg,
          'quantidade': bitola.pesoTotalKg,
          'qtde_original': bitola.pesoTotalKg,
          'cliente_id': pedido.cliente.id,
          'obra_id': pedido.obra.id,
          'unidade': '',
          'status': 'separado',
          'statusess_raw': [PedidoBitolaStatusModel.empty().toMap()],
          'valor_unitario': 0.0,
          'valor_total': 0.0,
        });
      }

      // ── 2. Tratar elementos ────────────────────────────────────────────────
      if (modo == 'substituir') {
        // Buscar IDs dos elementos existentes para deletar posições primeiro
        final existentes = await SupabaseService.client
            .from('elementos')
            .select('id')
            .eq('pedido_id', pedido.id);
        final existenteIds =
            existentes.map((e) => e['id'].toString()).toList();
        if (existenteIds.isNotEmpty) {
          await SupabaseService.client
              .from('elemento_posicoes')
              .delete()
              .filter('elemento_id', 'in', existenteIds);
          await SupabaseService.client
              .from('elemento_arquivos')
              .delete()
              .filter('elemento_id', 'in', existenteIds);
        }
        await SupabaseService.client
            .from('elementos')
            .delete()
            .eq('pedido_id', pedido.id);
      }

      // Inserir novos elementos
      for (final elem in extracao.elementos) {
        final elementoId = HashService.get;

        await SupabaseService.client.from('elementos').insert({
          'id': elementoId,
          'pedido_id': pedido.id,
          'nome': elem.nome,
          'qtde': elem.qtde,
          'status': 'aguardando',
        });

        // Inserir posições do elemento
        int osCounter = 1;
        for (final pos in elem.posicoes) {
          if (pos.produtoPcp == null) continue;

          await SupabaseService.client.from('elemento_posicoes').insert({
            'id': HashService.get,
            'elemento_id': elementoId,
            'nome': pos.nome,
            'numero_os': osCounter.toString().padLeft(3, '0'),
            'bitola_id': pos.produtoPcp!.id,
            'peso_kg': pos.pesoKg,
            'qtde': pos.qtde,
            'compr_unit': 0,
            'compr_corte': pos.comprCorte,
            'status': 'aguardando',
          });
          osCounter++;
        }
      }

      log('SpeImportacaoService: Importação concluída. '
          'Bitolas: ${extracao.bitolas.length}, '
          'Elementos: ${extracao.elementos.length}');
    } catch (e) {
      log('SpeImportacaoService.importarParaPedido erro: $e');
      rethrow;
    }
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  /// Tenta encontrar um BitolaModel do PCP correspondente à bitola do SPE.
  /// Match principal: codigoFinanceiro (campo obrigatório para importação).
  BitolaModel? _encontrarProdutoPcp(
    List<BitolaModel> bitolas,
    String bitolaNome,
    Map<String, dynamic>? bitolaData,
  ) {
    if (bitolaData == null) return null;

    // 1. Match por codigoFinanceiro (chave principal)
    final codigoFin =
        (bitolaData['codigo_financeiro'] ?? '').toString().trim();
    if (codigoFin.isNotEmpty) {
      final match = bitolas.firstWhereOrNull(
          (b) => b.codigoFinanceiro.trim() == codigoFin);
      if (match != null) return match;
    }

    // 2. Fallback: Match por nome + descricao (ex: "CA-50" + "8.0mm")
    final nomeB = (bitolaData['nome'] ?? '').toString().trim();
    final descB = (bitolaData['descricao'] ?? '').toString().trim();
    if (nomeB.isNotEmpty && descB.isNotEmpty) {
      final match = bitolas.firstWhereOrNull(
          (b) => b.nome.trim() == nomeB && b.descricao.trim() == descB);
      if (match != null) return match;
    }

    return null;
  }
}
