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
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
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

    // Listener reativo para elementos
    AppSupabaseClient.elementos.dataStream.listen.listen((allElementos) {
      if (_currentPedidoId != null) {
        final filtered = allElementos
            .where((e) => e.pedidoId == _currentPedidoId)
            .toList();
        // Ordenar alfabeticamente
        filtered.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        elementosStream.add(filtered);
      }
    });
  }

  String? _currentPedidoId;

  Future<void> _syncSummariesAndFilter(List<PedidoModel> all) async {
    loadingStream.add(true);
    final filtered = all.where((p) {
      final isVisible = p.step.isExibirArmacao;
      final matchesSearch = p.localizador.toLowerCase().contains(search.text.toLowerCase()) ||
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
    filtered.sort((a, b) => (a.deliveryAt ?? a.createdAt).compareTo(b.deliveryAt ?? b.createdAt));
    
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
          
          final prodId = pos['produto_id'].toString();
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

  ArmacaoSummary getSummary(String pedidoId) => _summaries[pedidoId] ?? ArmacaoSummary.empty();

  Future<void> onFetchElementos(PedidoModel pedido) async {
    try {
      _currentPedidoId = pedido.id;
      
      // Filtra o que já temos no AppSupabaseClient de forma reativa
      final filtered = AppSupabaseClient.elementos.data
          .where((e) => e.pedidoId == pedido.id)
          .toList();
      
      // Ordenar alfabeticamente pelo nome
      filtered.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      
      pedido.elementos.clear();
      pedido.elementos.addAll(filtered);
      elementosStream.add(filtered);
      
      // Atualizar resumo localmente 
      await updatePedidoSummary(pedido);
    } catch (e) {
      log('ArmacaoController.onFetchElementos erro: $e');
    }
  }

  void onSearch(String val) {
    _syncSummariesAndFilter(AppSupabaseClient.pedidos.data);
  }

  Future<void> updateElementoStatus(
      PedidoModel pedido, ElementoModel elemento, ElementoStatus newStatus) async {
    try {
      // Regra de negócio: Limite de produção simultânea
      if (newStatus == ElementoStatus.armando) {
        final countArmando =
            pedido.elementos.where((e) => e.status == ElementoStatus.armando).length;
        final limit = PreferencesService.maxElementosProducao.value;

        if (countArmando >= limit) {
          showInfoDialog('Limite Atingido: Você só pode armar até $limit elementos simultaneamente.');
          return;
        }
      }

      await SupabaseService.client
          .from('elementos')
          .update({'status': newStatus.name}).eq('id', elemento.id);

      // Atualizar localmente
      final index = pedido.elementos.indexWhere((e) => e.id == elemento.id);
      if (index != -1) {
        final updatedElemento = ElementoModel(
          id: elemento.id,
          pedidoId: elemento.pedidoId,
          nome: elemento.nome,
          qtde: elemento.qtde,
          createdAt: elemento.createdAt,
          posicoes: elemento.posicoes,
          arquivos: elemento.arquivos,
          status: newStatus,
        );
        pedido.elementos[index] = updatedElemento;
      }
      await updatePedidoSummary(pedido);

      // Verificação de finalização interativa
      final targetStep = automatizacaoCtrl.checkFinalizacaoArmacaoTargetStep(pedido);
      if (targetStep != null) {
        final confirm = await showConfirmDialog(
          'Finalização de Armação',
          'Todos os itens já foram marcados como pronto. Deseja arquivar este pedido?',
        );

        if (confirm) {
          await automatizacaoCtrl.executeFinalizacaoArmacao(pedido, targetStep);
          // Voltar para a tela de pedidos do armador
          Navigator.pop(contextGlobal);
        } else {
          // Se responder NÃO, apenas volta para a tela de pedidos
          Navigator.pop(contextGlobal);
        }
      }
    } catch (e) {
      log('Erro ao atualizar status do elemento: $e');
      showInfoDialog('Erro: Não foi possível atualizar o status.');
    }
  }

  Future<void> updatePedidoSummary(PedidoModel pedido) async {
    try {
      int totalQtd = 0;
      double totalPeso = 0;

      final Map<ElementoStatus, int> qtdPorStatus = {
        ElementoStatus.aguardando: 0,
        ElementoStatus.armando: 0,
        ElementoStatus.pronto: 0,
      };

      final Map<ElementoStatus, double> pesoPorStatus = {
        ElementoStatus.aguardando: 0,
        ElementoStatus.armando: 0,
        ElementoStatus.pronto: 0,
      };

      for (final e in pedido.elementos) {
        totalQtd += e.qtde;
        totalPeso += e.pesoTotal;

        qtdPorStatus[e.status] = (qtdPorStatus[e.status] ?? 0) + e.qtde;
        pesoPorStatus[e.status] = (pesoPorStatus[e.status] ?? 0) + e.pesoTotal;
      }

      final Map<String, dynamic> resume = {
        'total_qtd': totalQtd,
        'total_peso': totalPeso,
        'details': {
          'aguardando': {
            'qtd': qtdPorStatus[ElementoStatus.aguardando],
            'peso': pesoPorStatus[ElementoStatus.aguardando],
            'prcnt_qtd': totalQtd > 0 ? qtdPorStatus[ElementoStatus.aguardando]! / totalQtd : 0,
            'prcnt_peso': totalPeso > 0 ? pesoPorStatus[ElementoStatus.aguardando]! / totalPeso : 0,
          },
          'armando': {
            'qtd': qtdPorStatus[ElementoStatus.armando],
            'peso': pesoPorStatus[ElementoStatus.armando],
            'prcnt_qtd': totalQtd > 0 ? qtdPorStatus[ElementoStatus.armando]! / totalQtd : 0,
            'prcnt_peso': totalPeso > 0 ? pesoPorStatus[ElementoStatus.armando]! / totalPeso : 0,
          },
          'pronto': {
            'qtd': qtdPorStatus[ElementoStatus.pronto],
            'peso': pesoPorStatus[ElementoStatus.pronto],
            'prcnt_qtd': totalQtd > 0 ? qtdPorStatus[ElementoStatus.pronto]! / totalQtd : 0,
            'prcnt_peso': totalPeso > 0 ? pesoPorStatus[ElementoStatus.pronto]! / totalPeso : 0,
          },
        }
      };

      await SupabaseService.client
          .from('pedidos')
          .update({'armacao_resumo': resume})
          .eq('id', pedido.id);

      // Atualizar localmente no objeto pedido para UI refletir
      pedido.armacaoResumo.clear();
      pedido.armacaoResumo.addAll(resume);
    } catch (e) {
      log('Erro ao atualizar resumo do pedido: $e');
    }
  }
}
