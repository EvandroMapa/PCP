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
      final estoqueIdeal = estoque?.estoqueIdeal ?? 0.0;

      // Nível alvo: usa estoqueIdeal se definido, senão estoqueMinimo
      final nivelAlvo = estoqueIdeal > 0 ? estoqueIdeal : estoqueMinimo;

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

      // Calcula sugestão de compra (usando nível alvo)
      final necessidade = consumoPrevisto + nivelAlvo - saldoFisico - emPedido;
      final sugestao = necessidade > 0 ? necessidade : 0.0;
      final temDeficit = (saldoFisico - consumoPrevisto + emPedido) < nivelAlvo;

      itens.add(SimuladorCompraItem(
        produto: produto,
        saldoFisico: saldoFisico,
        consumoPrevisto: consumoPrevisto,
        emPedido: emPedido,
        estoqueMinimo: estoqueMinimo,
        estoqueIdeal: estoqueIdeal,
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

  /// Toggle da formatação de carga
  void onToggleFormatarCarga(bool valor) {
    if (model == null) return;
    model!.formatarCarga = valor;
    if (valor) {
      aplicarFormatacaoCarga();
    } else {
      // Recalcula sem formatação
      calcularNecessidades();
    }
  }

  /// Aplica formatação de carga redistribuindo quantidades
  void aplicarFormatacaoCarga() {
    if (model == null) return;
    final pesoAlvo = model!.pesoAlvoValue;
    final multiplo = model!.multiploValue;
    final itens = model!.itens;

    if (pesoAlvo <= 0) return;

    // 1. Necessidades base de cada produto
    final necessidades = <double>[];
    for (final item in itens) {
      necessidades.add(item.necessidade);
    }
    final totalNecessidade = necessidades.fold(0.0, (s, n) => s + n);

    // 2. Se a necessidade já supera o peso-alvo, apenas arredondar
    if (totalNecessidade >= pesoAlvo) {
      for (int i = 0; i < itens.length; i++) {
        final qty = _arredondar(necessidades[i], multiplo);
        itens[i].quantidadeSugerida.text =
            qty > 0 ? qty.toStringAsFixed(3) : '';
        itens[i].incluir = qty > 0;
      }
      modelStream.update();
      return;
    }

    // 3. Distribuir a sobra proporcionalmente pelo nivelAlvo
    final sobra = pesoAlvo - totalNecessidade;
    final somaNiveis = itens.fold(
        0.0, (s, i) => s + (i.nivelAlvo > 0 ? i.nivelAlvo : 1.0));

    final quantidades = <double>[];
    for (int i = 0; i < itens.length; i++) {
      final peso =
          itens[i].nivelAlvo > 0 ? itens[i].nivelAlvo : 1.0;
      final proporcional = sobra * (peso / somaNiveis);
      quantidades.add(necessidades[i] + proporcional);
    }

    // 4. Arredondar cada quantidade
    for (int i = 0; i < itens.length; i++) {
      final qty = _arredondar(quantidades[i], multiplo);
      itens[i].quantidadeSugerida.text =
          qty > 0 ? qty.toStringAsFixed(3) : '';
      itens[i].incluir = qty > 0;
    }

    modelStream.update();
  }

  /// Arredonda para o múltiplo mais próximo (para cima)
  double _arredondar(double valor, double multiplo) {
    if (multiplo <= 0 || valor <= 0) return valor;
    return (valor / multiplo).ceil() * multiplo;
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
