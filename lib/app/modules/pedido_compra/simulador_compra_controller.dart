import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';

import 'package:aco_plus/app/modules/pedido_compra/simulador_compra_view_model.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
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

    final produtos = BackendClient.bitolas.data.toList()
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

    // Preserva config de carga do model anterior
    final oldModel = model;
    final newModel = SimuladorCompraModel(itens: itens);
    if (oldModel != null) {
      // Preserva config de múltiplo e peso-alvo, mas formatarCarga começa OFF
      newModel.pesoAlvoCarga.text = oldModel.pesoAlvoCarga.text;
      newModel.multiploArredondamento.text =
          oldModel.multiploArredondamento.text;
    }

    // sugestaoBase = déficit arredondado pelo múltiplo (read-only, sempre)
    // quantidadeSugerida = inicia igual à sugestaoBase (editável)
    final multiplo = newModel.multiploValue;
    for (final item in itens) {
      final base = item.necessidade;
      final arredondado = multiplo > 0 && base > 0
          ? _arredondar(base, multiplo)
          : base;
      item.sugestaoBase = arredondado; // déficit arredondado pelo múltiplo
      item.quantidadeSugerida.text =
          arredondado > 0 ? arredondado.toStringAsFixed(0) : '';
    }

    modelStream.add(newModel);
  }

  /// Toggle incluir/excluir item
  void onToggleItem(SimuladorCompraItem item) {
    item.incluir = !item.incluir;
    if (!item.incluir) {
      item.quantidadeSugerida.text = '';
    } else if (item.quantidadeSugerida.text.isEmpty && item.sugestaoBase > 0) {
      item.quantidadeSugerida.text = item.sugestaoBase.toStringAsFixed(0);
    }
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

  /// Aplica um percentual global (0.0 a 2.0) redistribuindo proporcionalmente.
  /// Cada item incluído recebe: qtd = round(sugestaoBase * pct, múltiplo).
  /// Desativa "Formatar Carga" automaticamente.
  void onAjustarPercentual(double pct) {
    if (model == null) return;

    // Desativa Formatar Carga ao usar o slider
    model!.formatarCarga = false;

    final multiplo = model!.multiploValue;

    for (final item in model!.itens) {
      if (!item.incluir) continue;
      if (item.sugestaoBase <= 0) continue;

      final novaQtd = item.sugestaoBase * pct;
      final arredondado = multiplo > 0 && novaQtd > 0
          ? _arredondar(novaQtd, multiplo)
          : novaQtd;

      item.quantidadeSugerida.text =
          arredondado > 0 ? arredondado.toStringAsFixed(0) : '';
    }

    modelStream.update();
  }

  /// Incrementa (+) ou decrementa (−) exatamente 1 múltiplo em cada item selecionado.
  /// Desativa "Formatar Carga" automaticamente.
  void onIncrementarMultiplo(bool adicionar) {
    if (model == null) return;

    // Desativa Formatar Carga ao usar os botões ±
    model!.formatarCarga = false;

    final multiplo = model!.multiploValue > 0 ? model!.multiploValue : 1000;

    for (final item in model!.itens) {
      if (!item.incluir) continue;

      final atual = item.quantidadeDigitada;
      final nova = adicionar ? atual + multiplo : (atual - multiplo).clamp(0.0, double.infinity);
      item.quantidadeSugerida.text =
          nova > 0 ? nova.toStringAsFixed(0) : '';
    }

    modelStream.update();
  }

  /// Toggle da formatação de carga
  void onToggleFormatarCarga(bool valor) {
    if (model == null) return;
    model!.formatarCarga = valor;
    if (valor) {
      aplicarFormatacaoCarga();
    } else {
      // Recalcula sem formatação (mantém arredondamento)
      calcularNecessidades();
    }
  }

  /// Aplica arredondamento quando o usuário altera o campo múltiplo
  void onMultiploAlterado() {
    if (model == null) return;
    if (model!.formatarCarga) {
      aplicarFormatacaoCarga();
    } else {
      calcularNecessidades();
    }
  }

  /// Aplica formatação de carga redistribuindo quantidades
  /// Recalcula do zero a partir da sugestaoBase de cada item marcado
  void aplicarFormatacaoCarga() {
    if (model == null) return;
    final pedidoMinimo = model!.pesoAlvoValue;
    final multiplo = model!.multiploValue;

    if (pedidoMinimo <= 0) return;

    // 1. Pega os itens selecionados
    final selecionados = model!.itens.where((i) => i.incluir).toList();
    if (selecionados.isEmpty) {
      NotificationService.showNegative(
        'Nenhum item selecionado',
        'Marque ao menos um produto para formatar a carga',
        position: NotificationPosition.bottom,
      );
      return;
    }

    // 2. Soma das sugestões base dos itens marcados
    final totalBase = selecionados.fold(0.0, (s, i) => s + i.sugestaoBase);

    // 3. Se a sugestão base já atinge o pedido mínimo, apenas arredondar
    if (totalBase >= pedidoMinimo) {
      for (final item in selecionados) {
        final arredondado = multiplo > 0 && item.sugestaoBase > 0
            ? _arredondar(item.sugestaoBase, multiplo)
            : item.sugestaoBase;
        item.quantidadeSugerida.text =
            arredondado > 0 ? arredondado.toStringAsFixed(0) : '';
      }
      modelStream.update();
      return;
    }

    // 4. Distribuir a diferença (pedidoMinimo - totalBase) proporcionalmente
    final falta = pedidoMinimo - totalBase;
    final somaNiveis = selecionados.fold(
        0.0, (s, i) => s + (i.nivelAlvo > 0 ? i.nivelAlvo : 1.0));

    for (final item in selecionados) {
      final peso = item.nivelAlvo > 0 ? item.nivelAlvo : 1.0;
      final adicional = falta * (peso / somaNiveis);
      final novaQtd = item.sugestaoBase + adicional;
      final arredondado = multiplo > 0
          ? _arredondar(novaQtd, multiplo)
          : novaQtd;
      item.quantidadeSugerida.text =
          arredondado > 0 ? arredondado.toStringAsFixed(0) : '';
    }

    modelStream.update();
  }

  /// Arredonda para o múltiplo mais próximo (para cima)
  double _arredondar(double valor, double multiplo) {
    if (multiplo <= 0 || valor <= 0) return valor;
    return (valor / multiplo).ceil() * multiplo;
  }

  /// Gera o pedido de compra a partir da sugestão
  Future<void> onGerarPedido(BuildContext context) async {
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

    // Confirmação simples — fornecedor será escolhido ao confirmar o pedido
    if (!context.mounted) return;
    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shopping_cart_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('Gerar Pedido'),
          ],
        ),
        content: Text(
          '${selecionados.length} item${selecionados.length > 1 ? 's' : ''} · '
          '${model!.totalSugerido.toStringAsFixed(0)} kg\n\n'
          'O fornecedor será selecionado ao confirmar o pedido.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Gerar Pedido'),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    // Exibe loading
    showLoadingDialog();

    try {
      final usuarioNome = usuarioCtrl.usuario?.nome;
      final grupoId = HashService.get;

      for (final item in selecionados) {
        final pedido = PedidoCompraModel.novo(
          grupoId: grupoId,
          produtoId: item.produto.id,
          fabricanteId: '', // fornecedor definido na confirmação
          quantidade: item.quantidadeDigitada,
          usuarioNome: usuarioNome,
        );
        await BackendClient.pedidosCompra.add(pedido);
      }

      // Fecha loading
      if (context.mounted) Navigator.pop(context);

      NotificationService.showPositive(
        'Pedido gerado',
        '${selecionados.length} item${selecionados.length > 1 ? 's' : ''} · '
            '${model!.totalSugerido.toStringAsFixed(0)} kg — selecione o fornecedor ao confirmar',
        position: NotificationPosition.bottom,
      );

      // Volta para a lista de pedidos
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      // Fecha loading em caso de erro
      if (context.mounted) Navigator.pop(context);

      NotificationService.showNegative(
        'Erro ao gerar pedido',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }
}
