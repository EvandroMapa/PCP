import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_controller.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_view_model.dart';
import 'package:aco_plus/app/modules/pedido_compra/simulador_compra_view_model.dart';
import 'package:aco_plus/app/modules/pedido_compra/ui/pedido_compra_create_page.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final simuladorCompraCtrl = SimuladorCompraController();

class SimuladorCompraController {
  static final SimuladorCompraController _instance =
      SimuladorCompraController._();
  SimuladorCompraController._();
  factory SimuladorCompraController() => _instance;

  final AppStream<SimuladorCompraModel?> modelStream =
      AppStream<SimuladorCompraModel?>.seed(null);
  SimuladorCompraModel? get model => modelStream.value;

  /// Calcula as necessidades de compra para todos os produtos
  void calcularNecessidades() {
    // Garante que o relatório de consumo esteja atualizado
    if (!relatorioCtrl.pedidoViewModelStream.hasValue) {
      relatorioCtrl.pedidoViewModelStream.add(RelatorioPedidoViewModel());
    }
    relatorioCtrl.onCreateRelatorioPedido();

    final produtos = BackendClient.produtos.data.toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    final itens = <SimuladorCompraItem>[];

    for (final produto in produtos) {
      final estoque = BackendClient.estoques.getByProdutoId(produto.id);
      final saldoFisico = estoque?.quantidade ?? 0.0;
      final estoqueMinimo = estoque?.estoqueMinimo ?? 0.0;

      // Consumo previsto = total de kg em pedidos ativos (ordens não finalizadas)
      double consumoPrevisto = 0.0;
      try {
        consumoPrevisto = relatorioCtrl.getPedidosTotalPorBitola(produto);
      } catch (_) {
        // Se o relatório não estiver pronto, usa 0
      }

      // Total em pedidos de compra pendentes/confirmados
      final emPedido =
          BackendClient.pedidosCompra.getTotalPendenteByProdutoId(produto.id);

      // Calcula sugestão de compra
      final necessidade = consumoPrevisto + estoqueMinimo - saldoFisico - emPedido;
      final sugestao = necessidade > 0 ? necessidade : 0.0;
      final temDeficit = (saldoFisico - consumoPrevisto + emPedido) < estoqueMinimo;

      itens.add(SimuladorCompraItem(
        produto: produto,
        saldoFisico: saldoFisico,
        consumoPrevisto: consumoPrevisto,
        emPedido: emPedido,
        estoqueMinimo: estoqueMinimo,
        sugestaoInicial: sugestao,
        incluir: temDeficit && sugestao > 0,
      ));
    }

    modelStream.add(SimuladorCompraModel(itens: itens));
  }

  /// Toggle incluir/excluir item
  void onToggleItem(SimuladorCompraItem item) {
    item.incluir = !item.incluir;
    modelStream.update();
  }

  /// Selecionar todos com déficit
  void onSelecionarTodosComDeficit() {
    if (model == null) return;
    for (final item in model!.itens) {
      item.incluir = item.temDeficit && item.necessidade > 0;
    }
    modelStream.update();
  }

  /// Desmarcar todos
  void onDesmarcarTodos() {
    if (model == null) return;
    for (final item in model!.itens) {
      item.incluir = false;
    }
    modelStream.update();
  }

  /// Atualiza stream ao editar quantidade
  void onQuantidadeAlterada() {
    modelStream.update();
  }

  /// Gera o pedido de compra a partir da sugestão
  void onGerarPedido(BuildContext context) {
    if (model == null) return;

    final selecionados = model!.itensSelecionados;
    if (selecionados.isEmpty) {
      NotificationService.showNegative(
        'Nenhum item selecionado',
        'Marque ao menos um produto com quantidade para gerar o pedido',
        position: NotificationPosition.bottom,
      );
      return;
    }

    // Monta o form do PedidoCompraCreateModel com os itens sugeridos
    final createModel = PedidoCompraCreateModel();

    for (final item in selecionados) {
      final itemForm = PedidoCompraItemForm()
        ..produto = item.produto
        ..quantidade.text = item.quantidadeDigitada.toStringAsFixed(3);
      createModel.itens.add(itemForm);
    }

    // Envia para o controller de pedido de compra
    pedidoCompraCtrl.formStream.add(createModel);

    // Navega para a página de criação de pedido (já preenchida, sem fabricante)
    push(context, const PedidoCompraCreatePage());

    NotificationService.showPositive(
      'Sugestão aplicada',
      '${selecionados.length} item${selecionados.length > 1 ? 's' : ''} · ${model!.totalSugerido.toStringAsFixed(3)} kg',
      position: NotificationPosition.bottom,
    );
  }
}
