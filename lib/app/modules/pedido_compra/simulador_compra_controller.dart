import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
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

    // Preserva config de carga do model anterior
    final oldModel = model;
    final newModel = SimuladorCompraModel(itens: itens);
    if (oldModel != null) {
      // Preserva config de múltiplo e peso-alvo, mas formatarCarga começa OFF
      newModel.pesoAlvoCarga.text = oldModel.pesoAlvoCarga.text;
      newModel.multiploArredondamento.text =
          oldModel.multiploArredondamento.text;
    }

    // sugestaoBase = déficit bruto (nunca muda)
    // quantidadeSugerida = arredondado pelo múltiplo (editável)
    final multiplo = newModel.multiploValue;
    for (final item in itens) {
      final base = item.necessidade;
      item.sugestaoBase = base; // sempre o valor original
      final arredondado = multiplo > 0 && base > 0
          ? _arredondar(base, multiplo)
          : base;
      item.quantidadeSugerida.text =
          arredondado > 0 ? arredondado.toStringAsFixed(0) : '';
    }

    modelStream.add(newModel);
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
            qty > 0 ? qty.toStringAsFixed(0) : '';
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
          qty > 0 ? qty.toStringAsFixed(0) : '';
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

    // Pede o fabricante via dialog
    final fabricantes = [...BackendClient.fabricantes.data]
      ..sort((a, b) => a.nome.compareTo(b.nome));

    if (fabricantes.isEmpty) {
      NotificationService.showNegative(
        'Sem fabricantes',
        'Cadastre ao menos um fabricante antes de gerar o pedido',
        position: NotificationPosition.bottom,
      );
      return;
    }

    final fabricante = await showDialog<FabricanteModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selecionar Fabricante'),
        content: SizedBox(
          width: 320,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: fabricantes.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final fab = fabricantes[i];
              return ListTile(
                dense: true,
                title: Text(fab.nome,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(ctx, fab),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (fabricante == null) return;

    // Confirmação
    if (!context.mounted) return;
    final confirma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Pedido'),
        content: Text(
          'Gerar pedido para ${fabricante.nome} com '
          '${selecionados.length} item${selecionados.length > 1 ? 's' : ''} · '
          '${model!.totalSugerido.toStringAsFixed(0)} kg?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gerar Pedido'),
          ),
        ],
      ),
    );

    if (confirma != true) return;

    try {
      final usuarioNome = usuarioCtrl.usuario?.nome;
      final grupoId = HashService.get;

      for (final item in selecionados) {
        final pedido = PedidoCompraModel.novo(
          grupoId: grupoId,
          produtoId: item.produto.id,
          fabricanteId: fabricante.id,
          quantidade: item.quantidadeDigitada,
          usuarioNome: usuarioNome,
        );
        await BackendClient.pedidosCompra.add(pedido);
      }

      NotificationService.showPositive(
        'Pedido gerado',
        '${selecionados.length} item${selecionados.length > 1 ? 's' : ''} · '
            '${fabricante.nome} · ${model!.totalSugerido.toStringAsFixed(0)} kg',
        position: NotificationPosition.bottom,
      );

      // Volta para a lista de pedidos
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao gerar pedido',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }
}
