import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';

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
  final double metrosLineares; // metros lineares totais
  final BitolaModel? produtoPcp; // null se não encontrou match

  SpeBitolaExtraida({
    required this.bitolaNome,
    required this.pesoTotalKg,
    required this.metrosLineares,
    this.produtoPcp,
  });
}

class SpeElementoExtraido {
  final String nome; // ex: "V1"
  final int qtde;
  final List<SpePosicaoExtraida> posicoes;

  /// Peso unitário = soma dos pesos das posições (1 unidade do elemento)
  double get pesoUnitario => posicoes.fold(0.0, (s, p) => s + p.pesoKg);

  /// Peso total = pesoUnitário × quantidade de elementos
  double get pesoTotal => pesoUnitario * qtde;

  SpeElementoExtraido({
    required this.nome,
    required this.qtde,
    required this.posicoes,
  });
}

class SpePosicaoExtraida {
  final String nome; // ex: "Pos 1"
  final String bitolaNome;
  final double pesoKg; // peso real: metroLinear × qtde × massaFinal PCP
  final int qtde;
  final double metroLinear; // comprimento normal (soma dos trechos) em metros
  final BitolaModel? produtoPcp;

  SpePosicaoExtraida({
    required this.nome,
    required this.bitolaNome,
    required this.pesoKg,
    required this.qtde,
    required this.metroLinear,
    this.produtoPcp,
  });
}

/// Serviço de importação SPE → PCP.
/// Totalmente isolável — para remover, deletar este arquivo e suas referências.
///
/// LÓGICA DE PESO:
/// - Comprimento normal = soma dos trechos (campo `comprimentos` da posição SPE)
/// - Peso = metros lineares × massaFinal do PCP
/// - Comprimento de corte NÃO vai para o PCP (fica exclusivamente no SPE)
/// - Cada posição tem seu peso real (sem normalização)
/// - Σ posições = elemento, Σ elementos = pedido — tudo da mesma base
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
    final elementosDetalhamento = resultados[0];
    final bitolasSpe = resultados[1];

    // Mapear elementoId do pedido técnico → elemento do detalhamento
    final elementoIds =
        elementosDetalhamento.map((e) => e['id'].toString()).toList();

    // Buscar posições de todos os elementos do detalhamento
    final posicoesSpe = await _speClient.buscarPosicoesPorElementoIds(elementoIds);

    // Indexar bitolas SPE por ID (para match)
    final bitolasPorId = <String, Map<String, dynamic>>{};
    for (final b in bitolasSpe) {
      bitolasPorId[b['id'].toString()] = b;
    }

    // Produtos do PCP para match
    final produtosPcp = FirestoreClient.bitolas.data;

    // Cache de match bitola SPE → BitolaModel PCP
    final bitolaMatch = <String, BitolaModel?>{};

    // ── Processar cada elemento do pedido técnico ──────────────────────────
    final elementosExtraidos = <SpeElementoExtraido>[];
    final bitolaAcumuladoPeso = <String, double>{}; // bitolaNome → peso total kg
    final bitolaAcumuladoMetros = <String, double>{}; // bitolaNome → metros totais

    for (final elemPt in elementos) {
      final elementoId = elemPt['elemento_id']?.toString() ?? '';
      final elementoNome = elemPt['elemento_nome']?.toString() ?? '';
      final qtdeSolicitada =
          int.tryParse(elemPt['quantidade_solicitada']?.toString() ?? '1') ?? 1;

      // Filtrar posições deste elemento no detalhamento
      final posicoesDoElemento =
          posicoesSpe.where((p) => p['elemento_id'] == elementoId).toList();

      // ── Montar posições ────────────────────────────────────────────────
      final posicoesExtraidas = <SpePosicaoExtraida>[];
      int posCounter = 1;

      for (final pos in posicoesDoElemento) {
        final bitolaId = pos['bitola_id']?.toString() ?? '';
        final bitolaNome = pos['bitola_nome']?.toString() ?? '';
        final qtdePos = int.tryParse(pos['qtde']?.toString() ?? '1') ?? 1;
        final multiplicador =
            int.tryParse(pos['multiplicador']?.toString() ?? '1') ?? 1;

        final bitolaData = bitolasPorId[bitolaId];

        // Match com BitolaModel do PCP
        if (!bitolaMatch.containsKey(bitolaNome)) {
          bitolaMatch[bitolaNome] = _encontrarProdutoPcp(
            produtosPcp,
            bitolaNome,
            bitolaData,
          );
        }

        // ── METRO LINEAR: soma dos trechos (comprimento normal) ─────────
        // O campo `comprimentos` traz os trechos em cm.
        // O campo `variaveis` indica quais trechos têm comprimento variável.
        // O campo `variaveis_config` traz as medidas reais de cada instância.
        //
        // FIXO: {"T1": 163, "T2": 50, "T3": 50} → soma = 263 cm × qtde
        // VARIÁVEL: T1 varia por instância → medidas [40, 66, 92, ...]
        //   Cada medida é usada `multiplicador` vezes.
        //   Total = Σ (medida_T1 + T2_fixo + T3_fixo) × multiplicador
        final comprimentos = pos['comprimentos'] as Map<String, dynamic>? ?? {};
        final variaveis = pos['variaveis'] as Map<String, dynamic>? ?? {};
        final variaveisConfig = pos['variaveis_config'] as Map<String, dynamic>? ?? {};

        final temVariavel = variaveis.values.any((v) => v == true);

        double metroLinearTotal; // metros lineares de TODAS as peças da posição
        final qtdeTotal = qtdePos * multiplicador;

        if (temVariavel && variaveisConfig.isNotEmpty) {
          // ── POSIÇÃO COM TRECHOS VARIÁVEIS ─────────────────────────────
          // Separar trechos fixos e variáveis
          final trechosFixos = <String, double>{};
          final trechosVariaveis = <String, List<double>>{};

          for (final entry in comprimentos.entries) {
            final trecho = entry.key; // ex: "T1"
            if (variaveis[trecho] == true && variaveisConfig[trecho] != null) {
              // Trecho variável: pegar medidas reais
              final config = variaveisConfig[trecho] as Map<String, dynamic>;
              final medidas = (config['medidas'] as List?)
                  ?.map((m) => double.tryParse(m.toString()) ?? 0.0)
                  .toList() ?? [];
              trechosVariaveis[trecho] = medidas;
            } else {
              // Trecho fixo
              trechosFixos[trecho] = double.tryParse(entry.value.toString()) ?? 0.0;
            }
          }

          // Soma dos trechos fixos (igual para todas as peças)
          final somaFixosCm = trechosFixos.values.fold(0.0, (s, v) => s + v);

          // Para cada medida variável: comprimento total = medida + fixos
          // Cada medida é usada `multiplicador` vezes
          double somaMetrosCm = 0.0;
          if (trechosVariaveis.isNotEmpty) {
            // Pegar o trecho variável com medidas (normalmente 1 trecho variável)
            final medidasPrincipal = trechosVariaveis.values.first;
            for (final medida in medidasPrincipal) {
              somaMetrosCm += (medida + somaFixosCm) * multiplicador;
            }
          }

          metroLinearTotal = somaMetrosCm / 100.0; // cm → m
        } else {
          // ── POSIÇÃO COM TRECHOS FIXOS ─────────────────────────────────
          final somaTrechosCm = comprimentos.values.fold<double>(
            0.0,
            (s, v) => s + (double.tryParse(v.toString()) ?? 0.0),
          );
          metroLinearTotal = (somaTrechosCm / 100.0) * qtdeTotal; // cm → m × qtde
        }

        // Metro linear por unidade (para referência)
        final metroLinearUnit = qtdeTotal > 0 ? metroLinearTotal / qtdeTotal : 0.0;

        // ── PESO: metros totais × massaFinal do PCP (não do SPE) ─────────
        final massaFinalPcp = bitolaMatch[bitolaNome]?.massaFinal ?? 0.0;
        final pesoPos = double.parse((metroLinearTotal * massaFinalPcp).toStringAsFixed(2));

        posicoesExtraidas.add(SpePosicaoExtraida(
          nome: 'Pos ${pos['posicao'] ?? posCounter}',
          bitolaNome: bitolaNome,
          pesoKg: pesoPos,
          qtde: qtdeTotal,
          metroLinear: metroLinearUnit,
          produtoPcp: bitolaMatch[bitolaNome],
        ));

        posCounter++;
      }

      elementosExtraidos.add(SpeElementoExtraido(
        nome: elementoNome,
        qtde: qtdeSolicitada,
        posicoes: posicoesExtraidas,
      ));

      // ── Acumular peso/metros por bitola (considerando qtde do elemento) ─
      for (final pos in posicoesExtraidas) {
        final pesoProporcionado = pos.pesoKg * qtdeSolicitada;
        // metroLinearTotal da posição já inclui todas as peças
        // Aqui multiplicamos pela qtde do elemento
        final metrosProporcionados = pos.metroLinear * pos.qtde * qtdeSolicitada;
        bitolaAcumuladoPeso[pos.bitolaNome] =
            (bitolaAcumuladoPeso[pos.bitolaNome] ?? 0) + pesoProporcionado;
        bitolaAcumuladoMetros[pos.bitolaNome] =
            (bitolaAcumuladoMetros[pos.bitolaNome] ?? 0) + metrosProporcionados;
      }
    }

    // ── Montar lista de bitolas agrupadas ──────────────────────────────────
    // Garantir match para bitolas que não apareceram nas posições (ex: resumo_aco)
    final resumoAco = pedidoTecnico['resumo_aco'] as Map<String, dynamic>?;
    final resumoBitolasJson = resumoAco?['bitolas'] as Map<String, dynamic>?;
    if (resumoBitolasJson != null) {
      for (final bitolaNome in resumoBitolasJson.keys) {
        if (!bitolaMatch.containsKey(bitolaNome)) {
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
    }

    final bitolasExtraidas = bitolaAcumuladoPeso.entries.map((e) {
      return SpeBitolaExtraida(
        bitolaNome: e.key,
        pesoTotalKg: double.parse(e.value.toStringAsFixed(2)),
        metrosLineares: double.parse(
            (bitolaAcumuladoMetros[e.key] ?? 0).toStringAsFixed(2)),
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

        // Peso unitário = soma real das posições (sem normalização)
        final pesoUnit = elem.pesoUnitario;

        elementosBatch.add({
          'id': elementoId,
          'pedido_id': pedido.id,
          'nome': elem.nome,
          'qtde': elem.qtde,
          'peso_unitario': double.parse(pesoUnit.toStringAsFixed(2)),
          'status': 'aguardando',
        });

        // ── Posições com pesos reais (sem normalização) ─────────────────
        final posicoesValidas = elem.posicoes.where((p) => p.produtoPcp != null).toList();

        int osCounter = 1;
        for (final pos in posicoesValidas) {
          posicoesBatch.add({
            'id': HashService.get,
            'elemento_id': elementoId,
            'nome': pos.nome,
            'numero_os': osCounter.toString().padLeft(3, '0'),
            'bitola_id': pos.produtoPcp!.id,
            'peso_kg': double.parse(pos.pesoKg.toStringAsFixed(2)),
            'qtde': pos.qtde,
            'compr_unit': double.parse(pos.metroLinear.toStringAsFixed(3)),
            'compr_corte': 0,
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
