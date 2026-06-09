import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/elemento/elemento_supabase_collection.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
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
  /// Peso total vindo direto do banco do SPE (fonte de verdade)
  final double pesoTotalSpe;

  /// Usa o peso do SPE quando disponível; caso contrário recalcula
  double get pesoTotal =>
      pesoTotalSpe > 0 ? pesoTotalSpe : posicoes.fold(0.0, (s, p) => s + p.pesoKg) * qtde;

  SpeElementoExtraido({
    required this.nome,
    required this.qtde,
    required this.posicoes,
    this.pesoTotalSpe = 0,
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

    // Buscar elementos do detalhamento e bitolas do SPE em paralelo
    final resultados = await Future.wait([
      _speClient.buscarElementosDoDetalhamento(detalhamentoId),
      _speClient.buscarBitolas(),
    ]);
    final elementosDetalhamento = resultados[0] as List<Map<String, dynamic>>;
    final bitolasSpe = resultados[1] as List<Map<String, dynamic>>;

    // Mapear elementoId do pedido técnico → elemento do detalhamento
    final elementoIds =
        elementosDetalhamento.map((e) => e['id'].toString()).toList();

    // Buscar posições de todos os elementos do detalhamento
    final posicoesSpe = await _speClient.buscarPosicoesPorElementoIds(elementoIds);

    // Indexar bitolas por ID
    final bitolasPorId = <String, Map<String, dynamic>>{};
    for (final b in bitolasSpe) {
      bitolasPorId[b['id'].toString()] = b;
    }

    // Produtos do PCP para match
    final produtosPcp = FirestoreClient.bitolas.data;

    // ── Verificar se há resumo_aco pré-calculado pelo SPE ──────────────────
    final resumoAco = pedidoTecnico['resumo_aco'] as Map<String, dynamic>?;
    final resumoBitolasJson =
        resumoAco?['bitolas'] as Map<String, dynamic>?;
    final resumoElementosJson =
        resumoAco?['elementos'] as Map<String, dynamic>?;
    final temResumo =
        resumoBitolasJson != null && resumoBitolasJson.isNotEmpty;

    // ── Processar cada elemento do pedido técnico ──────────────────────────
    final elementosExtraidos = <SpeElementoExtraido>[];
    final bitolaAcumulado = <String, double>{}; // bitolaNome → peso total
    final bitolaMatch = <String, BitolaModel?>{}; // cache de match

    for (final elemPt in elementos) {
      final elementoId = elemPt['elemento_id']?.toString() ?? '';
      final elementoNome = elemPt['elemento_nome']?.toString() ?? '';
      final qtdeSolicitada =
          int.tryParse(elemPt['quantidade_solicitada']?.toString() ?? '1') ?? 1;

      // ── Peso do elemento: usar resumo_aco se disponível ─────────────────
      double pesoTotalElemento;
      if (temResumo && resumoElementosJson != null) {
        final elemResumo = resumoElementosJson[elementoNome] as Map<String, dynamic>?;
        pesoTotalElemento = elemResumo != null
            ? (elemResumo['peso'] as num?)?.toDouble() ?? 0.0
            : (double.tryParse(elemPt['peso_total']?.toString() ?? '0') ?? 0.0);
      } else {
        pesoTotalElemento =
            double.tryParse(elemPt['peso_total']?.toString() ?? '0') ?? 0.0;
      }

      // Filtrar posições deste elemento no detalhamento
      final posicoesDoElemento =
          posicoesSpe.where((p) => p['elemento_id'] == elementoId).toList();

      // ── Montar posições para exibição ───────────────────────────────────
      final posicoesExtraidas = <SpePosicaoExtraida>[];
      int posCounter = 1;

      for (final pos in posicoesDoElemento) {
        final bitolaId = pos['bitola_id']?.toString() ?? '';
        final bitolaNome = pos['bitola_nome']?.toString() ?? '';
        final qtdePos = int.tryParse(pos['qtde']?.toString() ?? '1') ?? 1;
        final multiplicador =
            int.tryParse(pos['multiplicador']?.toString() ?? '1') ?? 1;
        final comprCorte = double.tryParse(
                pos['comprimento_de_corte']?.toString() ?? '0') ??
            0.0;

        final bitolaData = bitolasPorId[bitolaId];

        // Match com BitolaModel do PCP
        if (!bitolaMatch.containsKey(bitolaNome)) {
          bitolaMatch[bitolaNome] = _encontrarProdutoPcp(
            produtosPcp,
            bitolaNome,
            bitolaData,
          );
        }

        // Peso real da posição: qtde × multiplicador × comprimento_de_corte × massa_final
        // Usa comprimento_de_corte (já inclui desconto de dobra) em vez de somar trechos
        final massaFinal = bitolaData != null
            ? (double.tryParse(
                    (bitolaData['massa_final'] ?? '0').toString()) ??
                0.0)
            : 0.0;
        final pesoPos = qtdePos * (comprCorte / 100.0) * massaFinal;

        posicoesExtraidas.add(SpePosicaoExtraida(
          nome: 'Pos ${pos['posicao'] ?? posCounter}',
          bitolaNome: bitolaNome,
          pesoKg: pesoPos,
          qtde: qtdePos * multiplicador,
          comprCorte: comprCorte,
          produtoPcp: bitolaMatch[bitolaNome],
        ));

        posCounter++;
      }

      elementosExtraidos.add(SpeElementoExtraido(
        nome: elementoNome,
        qtde: qtdeSolicitada,
        posicoes: posicoesExtraidas,
        pesoTotalSpe: double.parse(pesoTotalElemento.toStringAsFixed(2)),
      ));
    }

    // ── Montar lista de bitolas agrupadas ──────────────────────────────────
    if (temResumo) {
      // ── CAMINHO PRINCIPAL: usar resumo_aco do SPE (zero recálculo) ──────
      for (final entry in resumoBitolasJson!.entries) {
        final bitolaNome = entry.key;
        final dados = entry.value as Map<String, dynamic>;
        final peso = (dados['peso'] as num?)?.toDouble() ?? 0.0;
        bitolaAcumulado[bitolaNome] = peso;

        // Garantir match com PCP para bitolas do resumo
        if (!bitolaMatch.containsKey(bitolaNome)) {
          // Tentar encontrar bitolaData pelo nome
          final bitolaData = bitolasPorId.values
              .where((b) => b['nome']?.toString() == bitolaNome)
              .firstOrNull;
          bitolaMatch[bitolaNome] = _encontrarProdutoPcp(
            produtosPcp,
            bitolaNome,
            bitolaData,
          );
        }
      }
    } else {
      // ── FALLBACK: recalcular (pedidos antigos sem resumo_aco) ───────────
      for (final elem in elementosExtraidos) {
        for (final pos in elem.posicoes) {
          final pesoProporcionado = pos.pesoKg * elem.qtde;
          bitolaAcumulado[pos.bitolaNome] =
              (bitolaAcumulado[pos.bitolaNome] ?? 0) + pesoProporcionado;
        }
      }
    }

    final bitolasExtraidas = bitolaAcumulado.entries.map((e) {
      return SpeBitolaExtraida(
        bitolaNome: e.key,
        pesoTotalKg: double.parse(e.value.toStringAsFixed(2)),
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
    // Pausar streams Realtime durante importação (evita cascata de re-fetches)
    ElementoSupabaseCollection.isImportando = true;
    try {
      // ── 1. Tratar produtos (bitolas) ──────────────────────────────────────
      if (modo == 'substituir') {
        // Remover produtos existentes do pedido
        await SupabaseService.client
            .from('pedido_bitolas')
            .delete()
            .eq('pedido_id', pedido.id);
      }

      // Buscar bitolas já existentes no pedido (para modo 'acrescentar')
      final Map<String, Map<String, dynamic>> bitolaExistente = {};
      if (modo == 'acrescentar') {
        final existentes = await SupabaseService.client
            .from('pedido_bitolas')
            .select()
            .eq('pedido_id', pedido.id);
        for (final e in existentes) {
          final bitolaId = e['bitola_id']?.toString() ?? '';
          if (bitolaId.isNotEmpty) {
            bitolaExistente[bitolaId] = e;
          }
        }
      }

      // Inserir ou atualizar produtos
      final bitolaInsertBatch = <Map<String, dynamic>>[];
      final bitolaUpdateFutures = <Future>[];

      for (final bitola in extracao.bitolas) {
        if (bitola.produtoPcp == null) continue; // pular bitolas sem match

        final bitolaId = bitola.produtoPcp!.id;
        final existente = bitolaExistente[bitolaId];

        if (existente != null) {
          // Já existe — somar peso (agendar update)
          final pesoAtual =
              double.tryParse(existente['qtde']?.toString() ?? '0') ?? 0.0;
          final pesoOriginal = double.tryParse(
                  existente['qtde_original']?.toString() ?? '0') ??
              0.0;
          final novoPeso = pesoAtual + bitola.pesoTotalKg;
          final novoOriginal = pesoOriginal + bitola.pesoTotalKg;
          bitolaUpdateFutures.add(
            SupabaseService.client
                .from('pedido_bitolas')
                .update({
                  'qtde': novoPeso,
                  'quantidade': novoPeso,
                  'qtde_original': novoOriginal,
                })
                .eq('id', existente['id']),
          );
        } else {
          // Não existe — acumular para batch insert
          final produtoId = HashService.get;
          bitolaInsertBatch.add({
            'id': produtoId,
            'id_id': produtoId,
            'pedido_id': pedido.id,
            'bitola_id': bitolaId,
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
      }

      // Executar batch insert + updates em paralelo
      final futures = <Future>[...bitolaUpdateFutures];
      if (bitolaInsertBatch.isNotEmpty) {
        futures.add(
          SupabaseService.client.from('pedido_bitolas').insert(bitolaInsertBatch),
        );
      }
      if (futures.isNotEmpty) {
        await Future.wait(futures);
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
          await Future.wait([
            SupabaseService.client
                .from('elemento_posicoes')
                .delete()
                .filter('elemento_id', 'in', existenteIds),
            SupabaseService.client
                .from('elemento_arquivos')
                .delete()
                .filter('elemento_id', 'in', existenteIds),
          ]);
        }
        await SupabaseService.client
            .from('elementos')
            .delete()
            .eq('pedido_id', pedido.id);
      }


      // Inserir novos elementos e posições em lote (batch)
      final elementosBatch = <Map<String, dynamic>>[];
      final posicoesBatch = <Map<String, dynamic>>[];

      for (final elem in extracao.elementos) {
        final elementoId = HashService.get;

        // Peso unitário: precisão total (sem arredondar, para que peso_unit * qtde == pesoTotalSpe)
        final pesoUnit = elem.qtde > 0
            ? elem.pesoTotalSpe / elem.qtde
            : elem.pesoTotalSpe;

        elementosBatch.add({
          'id': elementoId,
          'pedido_id': pedido.id,
          'nome': elem.nome,
          'qtde': elem.qtde,
          'peso_unitario': pesoUnit,
          'status': 'aguardando',
        });

        // ── Posições com pesos normalizados ──────────────────────────────
        // A tabela posicoes do SPE não tem campo de peso — o peso é
        // calculado de dimensões × massa. Porém essa fórmula não replica
        // exatamente o cálculo interno do SPE (fatores de dobra, etc).
        // Solução: usamos o cálculo como PROPORÇÃO, mas o peso real
        // vem do pesoUnit do elemento (dado direto do SPE).
        // Resultado: Σ(posicao.peso_kg) = pesoUnit do elemento = dado real.
        final posicoesValidas = elem.posicoes.where((p) => p.produtoPcp != null).toList();
        final somaCalculada = posicoesValidas.fold(0.0, (s, p) => s + p.pesoKg);

        int osCounter = 1;
        for (final pos in posicoesValidas) {
          // Peso normalizado: mantém a proporção entre posições,
          // mas ajustado para que a soma = pesoUnit
          final pesoNormalizado = somaCalculada > 0
              ? (pos.pesoKg / somaCalculada) * pesoUnit
              : 0.0;

          posicoesBatch.add({
            'id': HashService.get,
            'elemento_id': elementoId,
            'nome': pos.nome,
            'numero_os': osCounter.toString().padLeft(3, '0'),
            'bitola_id': pos.produtoPcp!.id,
            'peso_kg': double.parse(pesoNormalizado.toStringAsFixed(3)),
            'qtde': pos.qtde,
            'compr_unit': 0,
            'compr_corte': pos.comprCorte,
            'status': 'aguardando',
          });
          osCounter++;
        }
      }

      // Batch insert: 1 request para elementos, 1 para posições
      if (elementosBatch.isNotEmpty) {
        await SupabaseService.client.from('elementos').insert(elementosBatch);
      }
      if (posicoesBatch.isNotEmpty) {
        await SupabaseService.client.from('elemento_posicoes').insert(posicoesBatch);
      }


      log('SpeImportacaoService: Importação concluída. '
          'Bitolas: ${extracao.bitolas.length}, '
          'Elementos: ${extracao.elementos.length}');
    } catch (e) {
      log('SpeImportacaoService.importarParaPedido erro: $e');
      rethrow;
    } finally {
      // Manter flag por mais 2s para bloquear Realtime de disparar refetches
      // O dialog fará o fetch focado (elementoCtrl.onFetch) logo em seguida
      Future.delayed(const Duration(seconds: 2), () {
        ElementoSupabaseCollection.isImportando = false;
      });
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
