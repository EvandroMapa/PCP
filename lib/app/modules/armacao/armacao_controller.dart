import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/elemento/elemento_supabase_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/modules/automatizacao/automatizacao_controller.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:flutter/material.dart';

final armacaoCtrl = ArmacaoController();

class ArmacaoSummary {
  final int totalElementos;
  final double pesoTotal;
  final Map<String, double> pesoPorBitola;

  ArmacaoSummary({
    required this.totalElementos,
    required this.pesoTotal,
    required this.pesoPorBitola,
  });

  factory ArmacaoSummary.empty() => ArmacaoSummary(
        totalElementos: 0,
        pesoTotal: 0,
        pesoPorBitola: {},
      );
}

class ArmacaoController {
  static final ArmacaoController _instance = ArmacaoController._();
  ArmacaoController._();
  factory ArmacaoController() => _instance;

  final TextController search = TextController();
  final AppStream<List<PedidoModel>> pedidosStream = AppStream.seed([]);
  final AppStream<List<ElementoModel>> elementosStream = AppStream.seed([]);
  final AppStream<bool> loadingStream = AppStream.seed(false);

  // Cache para evitar recarregar elementos desnecessariamente
  final Map<String, ArmacaoSummary> _summaries = {};

  void onInit() {
    AppSupabaseClient.pedidos.dataStream.listen.listen((pedidos) {
      _syncSummariesAndFilter(pedidos);
    });

    _registerElementosListener();
  }

  bool _elementosListenerRegistrado = false;

  /// Lock anti-flickering em DUAS CAMADAS (padrão AGENTS.md regra 8):
  ///
  /// Camada 1 — _statusLock (local): bloqueia o listener do dataStream no
  ///   _registerElementosListener, impedindo que eventos do Realtime
  ///   sobrescrevam o elementosStream enquanto o status está sendo atualizado.
  ///
  /// Camada 2 — ElementoSupabaseCollection.isStatusChanging (global): bloqueia
  ///   o _handlePosicaoRealtime e o _updateStreams no cache global, impedindo
  ///   que o re-fetch de 1.5s+fetch contamine o cache com estado anterior.
  ///   Sem essa camada, no PC (rede rápida), o re-fetch terminava após o lock
  ///   local expirar e sobrescrevia o elementosStream com o status antigo.
  bool _statusLock = false;
  Timer? _statusLockTimer;

  void _ativarStatusLock() {
    _statusLock = true;
    ElementoSupabaseCollection.isStatusChanging = true; // Camada 2
    _statusLockTimer?.cancel();
    _statusLockTimer = Timer(const Duration(milliseconds: 4000), () {
      // Libera camada 2 primeiro (permite que Realtime atualize o cache)
      ElementoSupabaseCollection.isStatusChanging = false;
      // Em seguida libera camada 1 (permite que o listener local leia o cache já correto)
      _statusLock = false;
    });
  }

  void _liberarStatusLock() {
    _statusLockTimer?.cancel();
    _statusLockTimer = Timer(const Duration(milliseconds: 4000), () {
      ElementoSupabaseCollection.isStatusChanging = false; // Camada 2
      _statusLock = false; // Camada 1
    });
  }

  /// Garante que o lock global seja sempre liberado ao sair da tela.
  void liberarLockSeAtivo() {
    _statusLockTimer?.cancel();
    _statusLock = false;
    ElementoSupabaseCollection.isStatusChanging = false;
  }

  /// Registra o listener reativo de elementos UMA única vez.
  /// Chamado tanto no onInit() (via ArmacaoPage) quanto no onFetchElementos()
  /// (via abertura direta pelo Painel Gerencial), garantindo que o Realtime
  /// funcione em ambos os fluxos de navegação.
  void _registerElementosListener() {
    if (_elementosListenerRegistrado) return;
    _elementosListenerRegistrado = true;

    AppSupabaseClient.elementos.dataStream.listen.listen((allElementos) {
      // Lock ativo: mudança de status em andamento ou recém concluída.
      // Ignorar evento do Realtime para evitar sobrescrever a UI otimista.
      if (_statusLock) return;

      if (_currentPedidoId != null) {
        log('ArmacaoController: Recebendo atualização de elementos para Pedido $_currentPedidoId');
        final filtered =
            allElementos.where((e) => e.pedidoId == _currentPedidoId).toList();
        // Ordenar alfabeticamente A-Z
        filtered.sort((a, b) =>
            a.nome.toLowerCase().trim().compareTo(b.nome.toLowerCase().trim()));
        elementosStream.add(filtered);

        // Recalcula o resumo do pedido corrente diretamente, sem esperar
        // o ciclo completo de re-fetch de pedidos (reduz latência na tela).
        if (_currentPedido != null) {
          _currentPedido!
            .elementos
            ..clear()
            ..addAll(filtered);
          updatePedidoSummary(_currentPedido!);
        }
      }
    });
  }

  String? _currentPedidoId;
  PedidoModel? _currentPedido;

  Future<void> _syncSummariesAndFilter(List<PedidoModel> all) async {
    loadingStream.add(true);
    final filtered = all.where((p) {
      final isVisible = p.step.isExibirArmacao;
      final matchesSearch =
          p.localizador.toLowerCase().contains(search.text.toLowerCase()) ||
              p.cliente.nome.toLowerCase().contains(search.text.toLowerCase());
      return isVisible && matchesSearch;
    }).toList();

    // Buscar sumários para os pedidos filtrados que ainda não temos
    for (final p in filtered) {
      if (!_summaries.containsKey(p.id)) {
        _summaries[p.id] = await _fetchSummary(p.id);
      }
    }

    // Ordenar por data de entrega ou criação
    filtered.sort((a, b) =>
        (a.deliveryAt ?? a.createdAt).compareTo(b.deliveryAt ?? b.createdAt));

    pedidosStream.add(filtered);
    loadingStream.add(false);
  }

  Future<ArmacaoSummary> _fetchSummary(String pedidoId) async {
    try {
      // Buscar elementos e suas posições
      final elementosRaw = await SupabaseService.client
          .from('elementos')
          .select()
          .eq('pedido_id', pedidoId);

      double pesoTotal = 0;
      int totalElementos = 0;
      final Map<String, double> pesoPorBitola = {};

      for (final e in elementosRaw) {
        final qtde = int.tryParse(e['qtde'].toString()) ?? 1;
        totalElementos += qtde;

        final posicoesRaw = await SupabaseService.client
            .from('elemento_posicoes')
            .select()
            .eq('elemento_id', e['id'].toString());

        for (final pos in posicoesRaw) {
          final pesoPos = double.tryParse(pos['peso_kg'].toString()) ?? 0.0;
          final pesoTotalPos = pesoPos * qtde;

          final prodId = pos['bitola_id'].toString();
          pesoPorBitola[prodId] = (pesoPorBitola[prodId] ?? 0) + pesoTotalPos;
          pesoTotal += pesoTotalPos;
        }
      }

      return ArmacaoSummary(
        totalElementos: totalElementos,
        pesoTotal: pesoTotal,
        pesoPorBitola: pesoPorBitola,
      );
    } catch (e) {
      log('Erro ao buscar sumário de armação: $e');
      return ArmacaoSummary.empty();
    }
  }

  ArmacaoSummary getSummary(String pedidoId) =>
      _summaries[pedidoId] ?? ArmacaoSummary.empty();

  Future<void> onFetchElementos(PedidoModel pedido) async {
    try {
      _currentPedidoId = pedido.id;
      _currentPedido = pedido;

      // Garante que o listener reativo está registrado, mesmo que onInit()
      // não tenha sido chamado (ex: acesso via Painel Gerencial).
      _registerElementosListener();

      // Tenta usar o cache global de elementos.
      // Quando acessado via Painel Gerencial (sem passar pelo ArmacaoPage),
      // o ElementoSupabaseCollection pode não ter feito o fetch inicial ainda,
      // resultando em cache vazio. Nesse caso, faz um fetch pontual APENAS dos
      // elementos desse pedido — evitando o ciclo pesado de re-fetch global
      // (todos elementos + posições em batches) que causava ~10s de atraso.
      List<ElementoModel> filtered =
          AppSupabaseClient.elementos.data
              .where((e) => e.pedidoId == pedido.id)
              .toList();

      if (filtered.isEmpty) {
        log('ArmacaoController.onFetchElementos: cache vazio para pedido ${pedido.id}, buscando diretamente do banco...');
        filtered = await _fetchElementosDoPedido(pedido.id);
      }

      // Ordenar alfabeticamente pelo nome A-Z
      filtered.sort((a, b) =>
          a.nome.toLowerCase().trim().compareTo(b.nome.toLowerCase().trim()));

      pedido.elementos.clear();
      pedido.elementos.addAll(filtered);
      elementosStream.add(filtered);

      // Persiste o resumo em background — NÃO aguarda para não bloquear
      // o loading spinner. A tela abre imediatamente com os dados do cache.
      updatePedidoSummary(pedido);
    } catch (e) {
      log('ArmacaoController.onFetchElementos erro: $e');
    }
  }

  /// Busca pontual dos elementos de um pedido específico, incluindo posições e arquivos.
  /// Usado quando o cache global ainda não foi carregado (acesso via Painel Gerencial).
  Future<List<ElementoModel>> _fetchElementosDoPedido(String pedidoId) async {
    try {
      final elementosRaw = await SupabaseService.client
          .from('elementos')
          .select()
          .eq('pedido_id', pedidoId)
          .order('nome');

      if (elementosRaw.isEmpty) return [];

      final eIds = elementosRaw.map((e) => e['id'].toString()).toList();

      final results = await Future.wait([
        SupabaseService.client
            .from('elemento_posicoes')
            .select()
            .filter('elemento_id', 'in', eIds),
        SupabaseService.client
            .from('elemento_arquivos')
            .select()
            .filter('elemento_id', 'in', eIds),
      ]);

      final allPosicoes = List<Map<String, dynamic>>.from(results[0]);
      final allArquivos = List<Map<String, dynamic>>.from(results[1]);

      return elementosRaw.map((eMap) {
        final eId = eMap['id'].toString();
        return ElementoModel.fromSupabaseMap(
          eMap,
          posicoesRaw:
              allPosicoes.where((p) => p['elemento_id'].toString() == eId).toList(),
          arquivosRaw:
              allArquivos.where((a) => a['elemento_id'].toString() == eId).toList(),
        );
      }).toList();
    } catch (e) {
      log('ArmacaoController._fetchElementosDoPedido erro: $e');
      return [];
    }
  }



  void onSearch(String val) {
    _syncSummariesAndFilter(AppSupabaseClient.pedidos.data);
  }

  Future<void> updateElementoStatus(PedidoModel pedido, ElementoModel elemento,
      ElementoStatus newStatus) async {
    // Usado SOMENTE para elementos com qtde == 1.
    // Elementos com qtde > 1 passam pelo openProgressoParcialDirect.
    try {
      int novoQtdePronto = 0;
      ElementoStatus statusFinal = newStatus;

      if (newStatus == ElementoStatus.pronto) {
        novoQtdePronto = elemento.qtde; // 1
        statusFinal = ElementoStatus.pronto;
      } else if (newStatus == ElementoStatus.armando) {
        novoQtdePronto = 0;
        statusFinal = ElementoStatus.armando;
      } else {
        novoQtdePronto = 0;
        statusFinal = ElementoStatus.aguardando;
      }

      await _applyStatusUpdate(
        pedido,
        elemento,
        statusFinal,
        novoQtdePronto: novoQtdePronto,
        novoQtdeArmando: 0, // qtde=1: sem rastreio por contador
      );
    } catch (e) {
      log('Erro ao atualizar status do elemento: $e');
      showInfoDialog('Erro: Não foi possível atualizar o status.');
    }
  }

  /// Abre o dialog de distribuição de peças (qtde > 1).
  /// O armador define independentemente quantas estão em produção e quantas já estão prontas.
  Future<void> openProgressoParcialDirect(
      PedidoModel pedido, ElementoModel elemento) async {
    try {
      final resultado = await _showDistribuicaoDialog(
        context: contextGlobal,
        elemento: elemento,
      );

      if (resultado == null) return; // Cancelou

      final novoArmando = resultado.$1;
      final novoPronto = resultado.$2;

      // Status derivado automaticamente dos contadores
      final ElementoStatus statusFinal;
      if (novoPronto >= elemento.qtde) {
        statusFinal = ElementoStatus.pronto;
      } else if (novoPronto > 0 || novoArmando > 0) {
        statusFinal = ElementoStatus.armando;
      } else {
        statusFinal = ElementoStatus.aguardando;
      }

      await _applyStatusUpdate(
        pedido,
        elemento,
        statusFinal,
        novoQtdePronto: novoPronto,
        novoQtdeArmando: novoArmando,
      );
    } catch (e) {
      log('Erro no fluxo direto de progresso: $e');
      showInfoDialog('Erro: Não foi possível atualizar o progresso.');
    }
  }

  /// Centraliza a verificação de limite dinâmico e persistência no banco e local
  Future<void> _applyStatusUpdate(
    PedidoModel pedido,
    ElementoModel elemento,
    ElementoStatus statusFinal, {
    required int novoQtdePronto,
    int novoQtdeArmando = 0,
  }) async {
    // Ativa o lock IMEDIATAMENTE (antes de qualquer await) para garantir que
    // nenhum evento Realtime sobrescreva o elementosStream durante o fluxo.
    // Antes estava APÓS a busca de config — havia uma janela aberta onde o
    // Realtime chegava antes do lock, causando flicker no PC (mouse).
    _ativarStatusLock();

    // 1. Buscar limite dinamicamente (Reatividade Administrativa)
    try {
      final configRaw = await SupabaseService.client
          .from('configs')
          .select()
          .eq('key', 'max_elementos_producao')
          .maybeSingle();
      if (configRaw != null) {
        final val = int.tryParse(configRaw['value'].toString());
        if (val != null) {
          PreferencesService.maxElementosProducao.add(val);
        }
      }
    } catch (e) {
      log('Erro ao atualizar limite dinâmico: $e');
    }

    // 2. Verificação de Limite de Produção Simultânea
    if (statusFinal == ElementoStatus.armando &&
        elemento.status != ElementoStatus.armando) {
      final countArmando = elementosStream.value
          .where((e) => e.status == ElementoStatus.armando)
          .length;
      final limit = PreferencesService.maxElementosProducao.value;

      if (countArmando >= limit) {
        // Limite atingido: libera o lock (nada foi alterado) e bloqueia.
        _liberarStatusLock();
        showInfoDialog('LIMITE ATINGIDO!\n\n'
            'O limite atual para este pedido é de $limit elementos simultâneos em produção.\n\n'
            'Conclua algum item ou peça ao administrador para aumentar o limite nas configurações.');
        return;
      }
    }

    // 3. Atualizar memória local ANTES da persistência (evita flash por realtime)
    final elementosLocal = elementosStream.value.toList();
    final index = elementosLocal.indexWhere((e) => e.id == elemento.id);
    if (index != -1) {
      final elementoAtualizado = elemento.copyWith(
        status: statusFinal,
        qtdePronto: novoQtdePronto,
        qtdeArmando: novoQtdeArmando,
      );
      elementosLocal[index] = elementoAtualizado;
      elementosStream.add(elementosLocal);

      // CRÍTICO: atualizar também o cache global via API oficial da collection.
      // Sem isso, quando o lock expirar (4s), o listener do dataStream lê o cache
      // com o estado ANTIGO e sobrescreve o elementosStream — revertendo a UI
      // visualmente mesmo com o banco já correto. O Realtime que normalmente
      // atualizaria o cache foi bloqueado pelo isStatusChanging durante o lock.
      //
      // updateLocalData emite dataStream, mas _registerElementosListener está
      // bloqueado por _statusLock → elementosStream NÃO é afetado por isso.
      // Só o cache global (AppSupabaseClient.elementos.data) é atualizado.
      AppSupabaseClient.elementos.updateLocalData([elementoAtualizado]);
    }

    // Atualizar no pedido também caso algo o leia diretamente
    final idxPedido = pedido.elementos.indexWhere((e) => e.id == elemento.id);
    if (idxPedido != -1 && index != -1) {
      pedido.elementos[idxPedido] = elementosLocal[index];
    }

    // 4. Calcular e aplicar o resumo localmente (UI já reflete antes do banco)
    await updatePedidoSummary(pedido);

    // 5. Persistência no Supabase
    await SupabaseService.client.from('elementos').update({
      'status': statusFinal.name,
      'qtde_pronto': novoQtdePronto,
      'qtde_armando': novoQtdeArmando,
    }).eq('id', elemento.id);

    // Registrar histórico de mudança de status
    // Inclui campos de rastreio de diagnóstico (status_anterior, qtde_armando, plataforma)
    // para identificar a origem de possíveis regressões tardias.
    final String plataforma = () {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android: return 'android';
        case TargetPlatform.iOS: return 'ios';
        case TargetPlatform.windows: return 'windows';
        case TargetPlatform.macOS: return 'macos';
        case TargetPlatform.linux: return 'linux';
        default: return 'web';
      }
    }();
    try {
      await SupabaseService.client.from('elemento_status_history').insert({
        'elemento_id': elemento.id,
        'pedido_id': pedido.id,
        'status': statusFinal.name,
        'qtde_pronto': novoQtdePronto,
        'status_anterior': elemento.status.name,
        'qtde_armando': novoQtdeArmando,
        'plataforma': plataforma,
      });
    } catch (e) {
      // Fallback: tenta sem os campos de diagnóstico (colunas podem não existir ainda)
      log('ArmacaoController: insert com campos extras falhou ($e), tentando sem extras...');
      try {
        await SupabaseService.client.from('elemento_status_history').insert({
          'elemento_id': elemento.id,
          'pedido_id': pedido.id,
          'status': statusFinal.name,
          'qtde_pronto': novoQtdePronto,
        });
      } catch (e2) {
        log('ArmacaoController: erro ao registrar histórico de status: $e2');
      }
    }

    // Renova o lock após todas as escritas (o Realtime dispara logo após o insert)
    _liberarStatusLock();

    // 6. Finalização de Pedido inteiro
    final todosProntos = pedido.elementos.every(
      (e) => e.status == ElementoStatus.pronto && e.qtdePronto >= e.qtde,
    );
    if (todosProntos) {
      final targetStep =
          automatizacaoCtrl.checkFinalizacaoArmacaoTargetStep(pedido);
      if (targetStep != null) {
        final confirm = await showConfirmDialog(
          'Finalização de Armação',
          'Todos os itens foram concluídos! Deseja finalizar este pedido?',
        );
        if (confirm) {
          await automatizacaoCtrl.executeFinalizacaoArmacao(pedido, targetStep);
        }
      }
    }
  }

  /// Dialog com DOIS contadores independentes: Armando e Prontas.
  /// Retorna (qtdeArmando, qtdePronto) ou null se cancelado.
  Future<(int, int)?> _showDistribuicaoDialog({
    required BuildContext context,
    required ElementoModel elemento,
  }) async {
    int selArmando = elemento.qtdeArmando;
    int selPronto = elemento.qtdePronto;

    return showDialog<(int, int)>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final aguardando = (elemento.qtde - selArmando - selPronto).clamp(0, elemento.qtde);

          // + ARMANDO: só se houver peças aguardando ainda
          final podeAdicionarArm = selArmando + selPronto < elemento.qtde;

          // + PRONTO: se houver peças armando (transfere) OU peças aguardando (adiciona direto)
          final podeAdicionarPro = selPronto < elemento.qtde;

          // Cor do botão de confirmar
          final Color corConfirmar;
          final String labelConfirmar;
          if (selPronto >= elemento.qtde) {
            corConfirmar = Colors.green[700]!;
            labelConfirmar = 'TUDO PRONTO ✔';
          } else if (selPronto > 0 || selArmando > 0) {
            corConfirmar = Colors.lime[800]!;
            labelConfirmar = 'SALVAR';
          } else {
            corConfirmar = Colors.blueGrey;
            labelConfirmar = 'SALVAR';
          }

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  elemento.nome,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${elemento.qtde} peças no total',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.normal),
                ),
              ],
            ),
            // SizedBox fixo: evita oscilação de tamanho ao alterar contadores
            content: SizedBox(
              width: double.infinity, // Row com Expanded precisa de largura bounded
              height: 160,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ── Contadores lado a lado ──────────────────────────────
                  Row(
                    children: [
                      // ARMANDO
                      Expanded(
                        child: _buildContador(
                          label: 'ARMANDO',
                          valor: selArmando,
                          cor: Colors.amber[800]!,
                          corFundo: Colors.amber[50]!,
                          onDecrement: selArmando > 0
                              ? () => setState(() => selArmando--)
                              : null,
                          onIncrement: podeAdicionarArm
                              ? () => setState(() => selArmando++)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // PRONTAS
                      Expanded(
                        child: _buildContador(
                          label: 'PRONTAS',
                          valor: selPronto,
                          cor: Colors.green[700]!,
                          corFundo: Colors.green[50]!,
                          onDecrement: selPronto > 0
                              ? () => setState(() => selPronto--)
                              : null,
                          // +PRONTO: debita de armando primeiro; se não, pega de aguardando
                          onIncrement: podeAdicionarPro
                              ? () => setState(() {
                                    if (selArmando > 0) selArmando--;
                                    selPronto++;
                                  })
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── Aguardando auto ───────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Aguardando',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$aguardando de ${elemento.qtde}',
                          style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: corConfirmar,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, (selArmando, selPronto)),
                child: Text(labelConfirmar),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Widget auxiliar para um contador com +/-
  Widget _buildContador({
    required String label,
    required int valor,
    required Color cor,
    required Color corFundo,
    required VoidCallback? onDecrement,
    required VoidCallback? onIncrement,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: corFundo,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cor, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onDecrement,
                icon: const Icon(Icons.remove),
                iconSize: 20,
                color: onDecrement != null ? cor : Colors.grey[300],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '$valor',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cor),
                ),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add),
                iconSize: 20,
                color: onIncrement != null ? cor : Colors.grey[300],
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> updatePedidoSummary(PedidoModel pedido) async {
    try {
      int totalQtd = 0;
      double totalPeso = 0;

      // Qtd e peso por status. Para elementos com qtdePronto parcial,
      // a fração pronta vai para "pronto" e o restante fica em "armando".
      final Map<ElementoStatus, double> qtdPorStatus = {
        ElementoStatus.aguardando: 0,
        ElementoStatus.armando: 0,
        ElementoStatus.pronto: 0,
      };
      final Map<ElementoStatus, double> pesoPorStatus = {
        ElementoStatus.aguardando: 0,
        ElementoStatus.armando: 0,
        ElementoStatus.pronto: 0,
      };

      for (final e in elementosStream.value) {
        totalQtd += e.qtde;
        totalPeso += e.pesoTotal;
        final ppUnit = e.qtde > 0 ? e.pesoTotal / e.qtde : 0.0;

        if (e.qtde == 1) {
          // qtde=1: status é a fonte de verdade
          switch (e.status) {
            case ElementoStatus.aguardando:
              qtdPorStatus[ElementoStatus.aguardando] =
                  (qtdPorStatus[ElementoStatus.aguardando] ?? 0) + 1;
              pesoPorStatus[ElementoStatus.aguardando] =
                  (pesoPorStatus[ElementoStatus.aguardando] ?? 0) + e.pesoTotal;
            case ElementoStatus.armando:
              qtdPorStatus[ElementoStatus.armando] =
                  (qtdPorStatus[ElementoStatus.armando] ?? 0) + 1;
              pesoPorStatus[ElementoStatus.armando] =
                  (pesoPorStatus[ElementoStatus.armando] ?? 0) + e.pesoTotal;
            case ElementoStatus.pronto:
              qtdPorStatus[ElementoStatus.pronto] =
                  (qtdPorStatus[ElementoStatus.pronto] ?? 0) + 1;
              pesoPorStatus[ElementoStatus.pronto] =
                  (pesoPorStatus[ElementoStatus.pronto] ?? 0) + e.pesoTotal;
          }
        } else {
          // qtde>1: contadores individuais são a fonte de verdade
          final prontoFrac = e.qtdePronto.toDouble();
          final armFrac = e.qtdeArmando.toDouble();
          final aguFrac = e.qtdeAguardando.toDouble(); // qtde - pronto - armando

          qtdPorStatus[ElementoStatus.pronto] =
              (qtdPorStatus[ElementoStatus.pronto] ?? 0) + prontoFrac;
          pesoPorStatus[ElementoStatus.pronto] =
              (pesoPorStatus[ElementoStatus.pronto] ?? 0) + (prontoFrac * ppUnit);

          qtdPorStatus[ElementoStatus.armando] =
              (qtdPorStatus[ElementoStatus.armando] ?? 0) + armFrac;
          pesoPorStatus[ElementoStatus.armando] =
              (pesoPorStatus[ElementoStatus.armando] ?? 0) + (armFrac * ppUnit);

          qtdPorStatus[ElementoStatus.aguardando] =
              (qtdPorStatus[ElementoStatus.aguardando] ?? 0) + aguFrac;
          pesoPorStatus[ElementoStatus.aguardando] =
              (pesoPorStatus[ElementoStatus.aguardando] ?? 0) + (aguFrac * ppUnit);
        }
      }

      final Map<String, dynamic> resume = {
        'total_qtd': totalQtd,
        'total_peso': totalPeso,
        'details': {
          'aguardando': {
            'qtd': qtdPorStatus[ElementoStatus.aguardando],
            'peso': pesoPorStatus[ElementoStatus.aguardando],
            'prcnt_qtd': totalQtd > 0
                ? qtdPorStatus[ElementoStatus.aguardando]! / totalQtd
                : 0,
            'prcnt_peso': totalPeso > 0
                ? pesoPorStatus[ElementoStatus.aguardando]! / totalPeso
                : 0,
          },
          'armando': {
            'qtd': qtdPorStatus[ElementoStatus.armando],
            'peso': pesoPorStatus[ElementoStatus.armando],
            'prcnt_qtd': totalQtd > 0
                ? qtdPorStatus[ElementoStatus.armando]! / totalQtd
                : 0,
            'prcnt_peso': totalPeso > 0
                ? pesoPorStatus[ElementoStatus.armando]! / totalPeso
                : 0,
          },
          'pronto': {
            'qtd': qtdPorStatus[ElementoStatus.pronto],
            'peso': pesoPorStatus[ElementoStatus.pronto],
            'prcnt_qtd': totalQtd > 0
                ? qtdPorStatus[ElementoStatus.pronto]! / totalQtd
                : 0,
            'prcnt_peso': totalPeso > 0
                ? pesoPorStatus[ElementoStatus.pronto]! / totalPeso
                : 0,
          },
        }
      };

      // Atualizar localmente no objeto pedido para UI refletir
      pedido.armacaoResumo.clear();
      pedido.armacaoResumo.addAll(resume);

      // Só agora persiste no banco (realtime trará o mesmo dado que já está na tela)
      await SupabaseService.client
          .from('pedidos')
          .update({'armacao_resumo': resume}).eq('id', pedido.id);
    } catch (e) {
      log('Erro ao atualizar resumo do pedido: $e');
    }
  }
}
