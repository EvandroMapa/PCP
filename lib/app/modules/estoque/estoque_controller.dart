import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_movimentacao_model.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/estoque/estoque_view_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
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

  final AppStream<EstoqueMovimentacaoFiltroModel> movimentacaoFiltroStream =
      AppStream<EstoqueMovimentacaoFiltroModel>.seed(
          EstoqueMovimentacaoFiltroModel());
  EstoqueMovimentacaoFiltroModel get movimentacaoFiltro =>
      movimentacaoFiltroStream.value;

  void onInit() {
    baseCtrl.appBarActionsStream
        .add(<Widget>[]); // limpa botões do módulo anterior
    utilsStream.add(EstoqueUtils());
    compraStream.add(EstoqueCompraCreateModel());
    relatorioFiltroStream.add(EstoqueRelatorioFiltroModel());
    movimentacaoFiltroStream.add(EstoqueMovimentacaoFiltroModel());
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

  /// Retorna o extrato cronológico de um produto no período do filtro de movimentação.
  /// Inclui o saldo inicial calculado a partir das movimentações anteriores ao período.
  (double saldoInicial, List<EstoqueLinhaMovimentacao> linhas)
      getExtratoPorProduto(BitolaModel produto) {
    final filtro = movimentacaoFiltro;
    final todasMovs = BackendClient.estoquesMovimentacao.data
        .where((e) => e.produtoId == produto.id)
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

    // Saldo inicial = soma das movimentações anteriores ao período
    final anteriores = todasMovs.where(
      (e) => e.dataHora
          .isBefore(filtro.dataInicio.copyWith(hour: 0, minute: 0, second: 0)),
    );
    final double saldoInicial =
        anteriores.fold(0.0, (s, e) => s + e.quantidade);

    // Movimentações dentro do período
    var movsPeriodo = todasMovs
        .where((e) => !e.dataHora.isBefore(
            filtro.dataInicio.copyWith(hour: 0, minute: 0, second: 0)))
        .toList();
    if (filtro.dataFim != null) {
      movsPeriodo = movsPeriodo
          .where((e) => e.dataHora.isBefore(
              filtro.dataFim!.copyWith(hour: 23, minute: 59, second: 59)))
          .toList();
    }

    // Monta linhas com saldo acumulado
    double saldo = saldoInicial;
    final linhas = <EstoqueLinhaMovimentacao>[];
    for (final mov in movsPeriodo) {
      saldo += mov.quantidade;
      linhas.add(EstoqueLinhaMovimentacao(
        produtoId: mov.produtoId,
        dataHora: mov.dataHora,
        tipoLabel: mov.tipo.label,
        tipoValue: mov.tipo.value,
        quantidade: mov.quantidade,
        saldoAcumulado: saldo,
        observacao: mov.observacao,
        ordemId: mov.ordemId,
        usuarioNome: mov.usuarioNome,
        isEntrada: mov.tipo.isEntrada,
      ));
    }

    return (saldoInicial, linhas);
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

  /// Salva estoque mínimo e ideal (sem editar saldo diretamente)
  Future<void> onEditarSaldo(EstoqueEditarSaldoModel form) async {
    try {
      final novoMinimo = form.estoqueMinimoValue;
      final novoIdeal = form.estoqueIdealValue;

      var estoque = BackendClient.estoques.getByProdutoId(form.produtoId);
      estoque ??= EstoqueModel.novo(form.produtoId);

      final estoqueAtualizado = estoque.copyWith(
        estoqueMinimo: novoMinimo,
        estoqueIdeal: novoIdeal,
        updatedAt: DateTime.now(),
      );
      await BackendClient.estoques.upsert(estoqueAtualizado);

      NotificationService.showPositive(
        'Parâmetros Atualizados',
        'Mínimo: ${novoMinimo.toStringAsFixed(3)} kg · Ideal: ${novoIdeal.toStringAsFixed(3)} kg',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao atualizar parâmetros',
        e.toString(),
        position: NotificationPosition.bottom,
      );
      rethrow;
    }
  }

  /// Lança um ajuste de estoque (entrada ou saída) com motivo obrigatório.
  /// Gera uma movimentação rastrevel do tipo ajusteEntrada ou ajusteSaida
  /// e registra no log de auditoria.
  Future<void> onLancarAjuste(EstoqueAjusteModel form) async {
    try {
      if (!form.isValid) {
        throw Exception('Informe a quantidade e o motivo do ajuste');
      }

      final qtde = form.isEntrada ? form.quantidadeValue : -form.quantidadeValue;

      var estoque = BackendClient.estoques.getByProdutoId(form.produtoId);
      estoque ??= EstoqueModel.novo(form.produtoId);

      final saldoAnterior = estoque.quantidade;
      final novaQtde = saldoAnterior + qtde;

      await BackendClient.estoques.upsert(
        estoque.copyWith(quantidade: novaQtde, updatedAt: DateTime.now()),
      );

      await BackendClient.estoquesMovimentacao.add(
        EstoqueMovimentacaoModel.novo(
          produtoId: form.produtoId,
          tipo: form.tipo,
          quantidade: qtde,
          observacao: form.motivo.text.trim(),
          usuarioNome: usuarioCtrl.usuario?.nome,
        ),
      );

      // Registra no log de auditoria (fire-and-forget)
      final nomeProduto = BackendClient.bitolas
          .getById(form.produtoId)
          .nome;
      AuditService.registrar(
        acao: 'ajuste_estoque',
        modulo: 'estoque',
        entidadeId: form.produtoId,
        entidadeLabel: nomeProduto,
        detalhes: {
          'tipo': form.tipo.value,
          'quantidade': form.quantidadeValue,
          'saldo_anterior': saldoAnterior,
          'saldo_novo': novaQtde,
          'motivo': form.motivo.text.trim(),
        },
      );

      NotificationService.showPositive(
        form.isEntrada ? 'Entrada lançada' : 'Saída lançada',
        '${form.quantidadeValue.toStringAsFixed(3)} kg · Saldo: ${novaQtde.toStringAsFixed(3)} kg',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao lançar ajuste',
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

    } catch (e) {
      // Não bloqueia a produção em caso de erro no estoque
      NotificationService.showNegative(
        'Erro na baixa de estoque',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  /// Retorna o saldo real de um produto calculando a soma de todas as
  /// movimentações registradas — independente do campo estoques.quantidade.
  /// Usa os dados já em memória, sem fetch extra.
  double getSaldoCalculado(String produtoId) {
    return BackendClient.estoquesMovimentacao.data
        .where((e) => e.produtoId == produtoId)
        .fold(0.0, (s, e) => s + e.quantidade);
  }

  /// Sincroniza o campo `quantidade` da tabela estoques com a soma real
  /// das movimentações para todos os produtos divergentes.
  /// Não gera movimentação — é uma correção técnica de dados.
  Future<void> sincronizarSaldos() async {
    try {
      final produtos = BackendClient.bitolas.data;
      int sincronizados = 0;

      for (final produto in produtos) {
        final saldoCalculado = getSaldoCalculado(produto.id);
        final estoque = BackendClient.estoques.getByProdutoId(produto.id);

        final saldoAtual = estoque?.quantidade ?? 0.0;
        final divergencia = (saldoCalculado - saldoAtual).abs();

        if (divergencia > 0.001) {
          final estoqueAtualizado = (estoque ?? EstoqueModel.novo(produto.id))
              .copyWith(
            quantidade: saldoCalculado,
            updatedAt: DateTime.now(),
          );
          await BackendClient.estoques.upsert(estoqueAtualizado);
          sincronizados++;
        }
      }

      // Recarrega os dados após sincronização
      await BackendClient.estoques.fetch();

      if (sincronizados == 0) {
        NotificationService.showNeutral(
          'Tudo sincronizado',
          'Nenhum produto com divergência de saldo encontrado.',
          position: NotificationPosition.bottom,
        );
      } else {
        NotificationService.showPositive(
          'Saldos sincronizados',
          '$sincronizados produto${sincronizados > 1 ? 's' : ''} corrigido${sincronizados > 1 ? 's' : ''} com base no histórico de movimentações.',
          position: NotificationPosition.bottom,
        );
      }
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao sincronizar saldos',
        e.toString(),
        position: NotificationPosition.bottom,
      );
      rethrow;
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
