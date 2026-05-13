import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_movimentacao_model.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/estoque/estoque_view_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final estoqueCtrl = EstoqueController();

class EstoqueController {
  static final EstoqueController _instance = EstoqueController._();
  EstoqueController._();
  factory EstoqueController() => _instance;

  final AppStream<EstoqueUtils> utilsStream =
      AppStream<EstoqueUtils>.seed(EstoqueUtils());
  EstoqueUtils get utils => utilsStream.value;

  final AppStream<EstoqueCompraCreateModel> compraStream =
      AppStream<EstoqueCompraCreateModel>.seed(EstoqueCompraCreateModel());
  EstoqueCompraCreateModel get compraForm => compraStream.value;

  final AppStream<EstoqueRelatorioFiltroModel> relatorioFiltroStream =
      AppStream<EstoqueRelatorioFiltroModel>.seed(
          EstoqueRelatorioFiltroModel());
  EstoqueRelatorioFiltroModel get relatorioFiltro =>
      relatorioFiltroStream.value;

  void onInit() {
    baseCtrl.appBarActionsStream
        .add(<Widget>[]); // limpa botões do módulo anterior
    utilsStream.add(EstoqueUtils());
    compraStream.add(EstoqueCompraCreateModel());
    relatorioFiltroStream.add(EstoqueRelatorioFiltroModel());
    BackendClient.estoques.fetch();
    BackendClient.estoquesMovimentacao.fetch();
  }

  List<EstoqueModel> getEstoqueFiltrado(String search) {
    final todos = BackendClient.estoques.data;
    if (search.length < 2) return todos;
    return todos
        .where((e) =>
            e.produto.nome.toCompare.contains(search.toCompare) ||
            e.produto.descricao.toCompare.contains(search.toCompare))
        .toList();
  }

  List<EstoqueMovimentacaoModel> getMovimentacoesFiltradas() {
    final filtro = relatorioFiltro;
    var movs = BackendClient.estoquesMovimentacao.data;

    if (filtro.produtoId != null) {
      movs = movs.where((e) => e.produtoId == filtro.produtoId).toList();
    }
    if (filtro.dataInicio != null) {
      movs = movs
          .where((e) => e.dataHora
              .isAfter(filtro.dataInicio!.subtract(const Duration(days: 1))))
          .toList();
    }
    if (filtro.dataFim != null) {
      movs = movs
          .where((e) =>
              e.dataHora.isBefore(filtro.dataFim!.add(const Duration(days: 1))))
          .toList();
    }
    return movs;
  }

  /// Edita o saldo de implantação de um produto
  Future<void> onEditarSaldo(EstoqueEditarSaldoModel form) async {
    try {
      final novaQtde = form.novoSaldoValue;
      final novoMinimo = form.estoqueMinimoValue;

      // Busca ou cria o registro de estoque
      var estoque = BackendClient.estoques.getByProdutoId(form.produtoId);
      estoque ??= EstoqueModel.novo(form.produtoId);

      final saldoAnterior = estoque.quantidade;
      final diff = novaQtde - saldoAnterior;

      // Atualiza saldo + estoque mínimo
      final estoqueAtualizado = estoque.copyWith(
        quantidade: novaQtde,
        estoqueMinimo: novoMinimo,
        updatedAt: DateTime.now(),
      );
      await BackendClient.estoques.upsert(estoqueAtualizado);

      // Registra movimentação de implantação (apenas se o saldo mudou)
      if (diff != 0) {
        await BackendClient.estoquesMovimentacao.add(
          EstoqueMovimentacaoModel.novo(
            produtoId: form.produtoId,
            tipo: EstoqueTipoMovimentacao.implantacao,
            quantidade: diff,
            observacao: 'Ajuste de implantação: $saldoAnterior kg → $novaQtde kg',
            usuarioNome: usuarioCtrl.usuario?.nome,
          ),
        );
      }

      NotificationService.showPositive(
        'Estoque Atualizado',
        'Saldo: ${novaQtde.toStringAsFixed(3)} kg · Mínimo: ${novoMinimo.toStringAsFixed(3)} kg',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao atualizar saldo',
        e.toString(),
        position: NotificationPosition.bottom,
      );
      rethrow;
    }
  }

  /// Registra uma entrada de compra (via form interno)
  Future<void> onRegistrarCompra() async {
    try {
      final form = compraForm;
      if (!form.isValid) {
        throw Exception('Preencha o produto e a quantidade corretamente');
      }

      final qtde = form.quantidadeValue;
      if (qtde <= 0) throw Exception('Quantidade deve ser maior que zero');

      await onRegistrarCompraManual(
        produtoId: form.produtoId!,
        quantidade: qtde,
        observacao:
            form.observacao.text.isNotEmpty ? form.observacao.text : null,
      );

      form.clear();
      compraStream.update();
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao registrar compra',
        e.toString(),
        position: NotificationPosition.bottom,
      );
      rethrow;
    }
  }

  /// Registra uma entrada de compra com parâmetros diretos (usado pelo PedidoCompraController)
  Future<void> onRegistrarCompraManual({
    required String produtoId,
    required double quantidade,
    String? observacao,
  }) async {
    try {
      if (quantidade <= 0)
        throw Exception('Quantidade deve ser maior que zero');

      var estoque = BackendClient.estoques.getByProdutoId(produtoId);
      estoque ??= EstoqueModel.novo(produtoId);

      final novaQtde = estoque.quantidade + quantidade;
      final estoqueAtualizado = estoque.copyWith(
        quantidade: novaQtde,
        updatedAt: DateTime.now(),
      );
      await BackendClient.estoques.upsert(estoqueAtualizado);

      await BackendClient.estoquesMovimentacao.add(
        EstoqueMovimentacaoModel.novo(
          produtoId: produtoId,
          tipo: EstoqueTipoMovimentacao.compra,
          quantidade: quantidade,
          observacao: observacao,
          usuarioNome: usuarioCtrl.usuario?.nome,
        ),
      );

      NotificationService.showPositive(
        'Compra Registrada',
        '${quantidade.toStringAsFixed(3)} kg adicionados ao estoque',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao registrar compra',
        e.toString(),
        position: NotificationPosition.bottom,
      );
      rethrow;
    }
  }

  /// Estorna uma entrada de compra (usado pelo PedidoCompraController ao desefetivar)
  Future<void> onEstornarCompraManual({
    required String produtoId,
    required double quantidade,
    String? observacao,
  }) async {
    try {
      if (quantidade <= 0)
        throw Exception('Quantidade deve ser maior que zero');

      var estoque = BackendClient.estoques.getByProdutoId(produtoId);
      estoque ??= EstoqueModel.novo(produtoId);

      final novaQtde = estoque.quantidade - quantidade;
      await BackendClient.estoques.upsert(
          estoque.copyWith(quantidade: novaQtde, updatedAt: DateTime.now()));

      await BackendClient.estoquesMovimentacao.add(
        EstoqueMovimentacaoModel.novo(
          produtoId: produtoId,
          tipo: EstoqueTipoMovimentacao.estorno,
          quantidade: -quantidade,
          observacao: observacao ?? 'Estorno de compra',
          usuarioNome: usuarioCtrl.usuario?.nome,
        ),
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao estornar compra',
        e.toString(),
        position: NotificationPosition.bottom,
      );
      rethrow;
    }
  }

  /// Baixa automática ao marcar item como pronto na ordem
  Future<void> baixarEstoque({
    required String produtoId,
    required double quantidade,
    required OrdemModel ordem,
  }) async {
    try {
      var estoque = BackendClient.estoques.getByProdutoId(produtoId);
      estoque ??= EstoqueModel.novo(produtoId);

      final novaQtde = estoque.quantidade - quantidade;
      final estoqueAtualizado = estoque.copyWith(
        quantidade: novaQtde,
        updatedAt: DateTime.now(),
      );
      await BackendClient.estoques.upsert(estoqueAtualizado);

      // Registra movimentação
      await BackendClient.estoquesMovimentacao.add(
        EstoqueMovimentacaoModel.novo(
          produtoId: produtoId,
          tipo: EstoqueTipoMovimentacao.baixaProducao,
          quantidade: -quantidade,
          observacao: 'Baixa da Ordem ${ordem.localizator}',
          ordemId: ordem.id,
          usuarioNome: usuarioCtrl.usuario?.nome,
        ),
      );

      // Aviso se saldo ficou negativo
      if (novaQtde < 0) {
        NotificationService.showPending(
          'Estoque negativo',
          'Produto ${estoque.produto.nome} com saldo negativo: ${novaQtde.toStringAsFixed(3)} kg',
        );
      }
    } catch (e) {
      // Não bloqueia a produção em caso de erro no estoque
      NotificationService.showNegative(
        'Erro na baixa de estoque',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  /// Estorno automático quando produto volta de PRONTO para outro status
  Future<void> estornarBaixa({
    required String produtoId,
    required double quantidade,
    required OrdemModel ordem,
  }) async {
    try {
      var estoque = BackendClient.estoques.getByProdutoId(produtoId);
      estoque ??= EstoqueModel.novo(produtoId);

      final novaQtde = estoque.quantidade + quantidade;
      final estoqueAtualizado = estoque.copyWith(
        quantidade: novaQtde,
        updatedAt: DateTime.now(),
      );
      await BackendClient.estoques.upsert(estoqueAtualizado);

      // Registra movimentação de estorno (tipo = estorno, quantidade positiva = devolução)
      await BackendClient.estoquesMovimentacao.add(
        EstoqueMovimentacaoModel.novo(
          produtoId: produtoId,
          tipo: EstoqueTipoMovimentacao.estorno,
          quantidade: quantidade,
          observacao: 'Estorno — Ordem ${ordem.localizator} voltou de Pronto',
          ordemId: ordem.id,
          usuarioNome: usuarioCtrl.usuario?.nome,
        ),
      );

      NotificationService.showNeutral(
        'Estoque estornado',
        'Quantidade devolvida: ${quantidade.toStringAsFixed(3)} kg',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      // Não bloqueia a operação em caso de erro
      NotificationService.showNegative(
        'Erro no estorno de estoque',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }
}
