import 'dart:developer';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
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

  /// Registra o listener reativo de elementos UMA única vez.
  /// Chamado tanto no onInit() (via ArmacaoPage) quanto no onFetchElementos()
  /// (via abertura direta pelo Painel Gerencial), garantindo que o Realtime
  /// funcione em ambos os fluxos de navegação.
  void _registerElementosListener() {
    if (_elementosListenerRegistrado) return;
    _elementosListenerRegistrado = true;

    AppSupabaseClient.elementos.dataStream.listen.listen((allElementos) {
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
          _currentPedido!.elementos
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

      // Filtra o que já temos no AppSupabaseClient de forma reativa
      final filtered = AppSupabaseClient.elementos.data
          .where((e) => e.pedidoId == pedido.id)
          .toList();

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



  void onSearch(String val) {
    _syncSummariesAndFilter(AppSupabaseClient.pedidos.data);
  }

  Future<void> updateElementoStatus(PedidoModel pedido, ElementoModel elemento,
      ElementoStatus newStatus) async {
    try {
      int novoQtdePronto = elemento.qtdePronto;
      ElementoStatus statusFinal = newStatus;

      // 2. Determinar status final planejado
      if (newStatus == ElementoStatus.pronto && elemento.qtde > 1) {
        final quantidadeEscolhida = await _showQtdeProntoDialog(
          context: contextGlobal,
          elemento: elemento,
        );
        if (quantidadeEscolhida == null) return; // Cancelou

        novoQtdePronto = quantidadeEscolhida;
        statusFinal = (novoQtdePronto >= elemento.qtde)
            ? ElementoStatus.pronto
            : ElementoStatus.armando;
      } else if (newStatus == ElementoStatus.pronto && elemento.qtde == 1) {
        novoQtdePronto = 1;
        statusFinal = ElementoStatus.pronto;
      } else if (newStatus == ElementoStatus.armando) {
        novoQtdePronto = 0; // Volta a armar, zera o progresso
        statusFinal = ElementoStatus.armando;
      } else if (newStatus == ElementoStatus.aguardando) {
        novoQtdePronto = 0; // Volta para aguardando, zera o progressodf
        statusFinal = ElementoStatus.aguardando;
      }

      await _applyStatusUpdate(pedido, elemento, statusFinal, novoQtdePronto);
    } catch (e) {
      log('Erro ao atualizar status do elemento: $e');
      showInfoDialog('Erro: Não foi possível atualizar o status.');
    }
  }

  /// Método direto de atualização de progresso para elementos com qtde > 1
  Future<void> openProgressoParcialDirect(
      PedidoModel pedido, ElementoModel elemento) async {
    try {
      final int? quantidadeEscolhida = await _showQtdeProntoDialog(
        context: contextGlobal,
        elemento: elemento,
      );

      if (quantidadeEscolhida == null) return; // Cancelou

      ElementoStatus statusFinal;
      if (quantidadeEscolhida == 0) {
        statusFinal = ElementoStatus.aguardando;
      } else if (quantidadeEscolhida >= elemento.qtde) {
        statusFinal = ElementoStatus.pronto;
      } else {
        statusFinal = ElementoStatus.armando;
      }

      await _applyStatusUpdate(
          pedido, elemento, statusFinal, quantidadeEscolhida);
    } catch (e) {
      log('Erro no fluxo direto de progresso: $e');
      showInfoDialog('Erro: Não foi possível atualizar o progresso.');
    }
  }

  /// Centraliza a verificação de limite dinâmico e persistência no banco e local
  Future<void> _applyStatusUpdate(PedidoModel pedido, ElementoModel elemento,
      ElementoStatus statusFinal, int novoQtdePronto) async {
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
      elementosLocal[index] = elemento.copyWith(
        status: statusFinal,
        qtdePronto: novoQtdePronto,
      );
      elementosStream.add(elementosLocal);
    }

    // Atualizar no pedido também caso algo o leia diretamente
    final idxPedido = pedido.elementos.indexWhere((e) => e.id == elemento.id);
    if (idxPedido != -1 && index != -1) {
      pedido.elementos[idxPedido] = elementosLocal[index];
    }

    // 4. Calcular e aplicar o resumo localmente (UI já reflete antes do banco)
    await updatePedidoSummary(pedido);

    // 5. Persistência no Supabase (o realtime vai trazer o mesmo dado que já está na tela)
    await SupabaseService.client.from('elementos').update({
      'status': statusFinal.name,
      'qtde_pronto': novoQtdePronto,
    }).eq('id', elemento.id);

    // Registrar histórico de mudança de status
    await SupabaseService.client.from('elemento_status_history').insert({
      'elemento_id': elemento.id,
      'pedido_id': pedido.id,
      'status': statusFinal.name,
      'qtde_pronto': novoQtdePronto,
    });

    // 5. Finalização de Pedido inteiro
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

  /// Diálogo para o armador informar quantas peças estão prontas
  Future<int?> _showQtdeProntoDialog({
    required BuildContext context,
    required ElementoModel elemento,
  }) async {
    int selecionado = elemento.qtdePronto;

    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Quantas peças prontas?\n${elemento.nome}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total de peças: ${elemento.qtde}\nAtualmente prontas: ${elemento.qtdePronto}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: selecionado > 0
                        ? () => setState(() => selecionado--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 32,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$selecionado / ${elemento.qtde}',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: selecionado < elemento.qtde
                        ? () => setState(() => selecionado++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 32,
                    color: Colors.green,
                  ),
                ],
              ),
              if (selecionado == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'O elemento voltará para AGUARDANDO.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (selecionado < elemento.qtde)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'As ${elemento.qtde - selecionado} peças restantes ficarão em ARMANDO.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    selecionado == 0 ? Colors.blueGrey : Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, selecionado),
              child: Text(
                selecionado == 0
                    ? 'P/ AGUARDANDO'
                    : (selecionado == elemento.qtde
                        ? 'CONFIRMAR PRONTO'
                        : 'SALVAR PROGRESSO'),
              ),
            ),
          ],
        ),
      ),
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

        if (e.status == ElementoStatus.aguardando) {
          qtdPorStatus[ElementoStatus.aguardando] =
              (qtdPorStatus[ElementoStatus.aguardando] ?? 0) + e.qtde;
          pesoPorStatus[ElementoStatus.aguardando] =
              (pesoPorStatus[ElementoStatus.aguardando] ?? 0) + e.pesoTotal;
        } else if (e.status == ElementoStatus.pronto) {
          qtdPorStatus[ElementoStatus.pronto] =
              (qtdPorStatus[ElementoStatus.pronto] ?? 0) + e.qtde;
          pesoPorStatus[ElementoStatus.pronto] =
              (pesoPorStatus[ElementoStatus.pronto] ?? 0) + e.pesoTotal;
        } else {
          // armando — pode ter progresso parcial
          final qtdeProntoFrac = e.qtdePronto.toDouble();
          final qtdeArmandoFrac = (e.qtde - e.qtdePronto).toDouble();
          final pesoPorUnidade = e.qtde > 0 ? e.pesoTotal / e.qtde : 0.0;

          qtdPorStatus[ElementoStatus.pronto] =
              (qtdPorStatus[ElementoStatus.pronto] ?? 0) + qtdeProntoFrac;
          pesoPorStatus[ElementoStatus.pronto] =
              (pesoPorStatus[ElementoStatus.pronto] ?? 0) +
                  (qtdeProntoFrac * pesoPorUnidade);

          qtdPorStatus[ElementoStatus.armando] =
              (qtdPorStatus[ElementoStatus.armando] ?? 0) + qtdeArmandoFrac;
          pesoPorStatus[ElementoStatus.armando] =
              (pesoPorStatus[ElementoStatus.armando] ?? 0) +
                  (qtdeArmandoFrac * pesoPorUnidade);
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
