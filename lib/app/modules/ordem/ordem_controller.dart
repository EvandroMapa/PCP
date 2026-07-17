import 'dart:async';
import 'dart:developer';
import 'package:aco_plus/app/core/utils/posicao_progresso_helper.dart';

import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/enums/materia_prima_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_status_bitolas.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/ordem/ordem_supabase_collection.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/utils/logo_helper.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/enums/sort_type.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/pdf_download_service/pdf_download_service_mobile.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/automatizacao/automatizacao_controller.dart';
import 'package:aco_plus/app/modules/ordem/ordem_timeline_register.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/bitola/ordem_pedido_bitola_pause_motivo_bottom.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem_etiquetas_pdf_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem_bitola_status_bottom.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem_bitolas_status_bottom.dart';
import 'package:aco_plus/app/modules/ordem/view_models/ordem_view_model.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_ordem_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:pdf/widgets.dart' as pw;

final ordemCtrl = OrdemController();

class OrdemController {
  static final OrdemController _instance = OrdemController._();

  OrdemController._();

  factory OrdemController() => _instance;

  /// Flag que indica quando o usuário está acessando pelo modo operador
  /// (rota /operador standalone). Permite que admins com acesso operador
  /// usem a interface de operador sem depender de `usuario.isOperador`.
  bool modoOperadorAtivo = false;

  /// Verifica se deve usar a interface de operador.
  /// Retorna true quando:
  /// - O usuário é operador puro (não-admin), OU
  /// - O admin está acessando pela rota standalone de operador
  bool get isEmModoOperador =>
      usuario.isOperador || (modoOperadorAtivo && usuario.temAcessoOperador);

  final AppStream<OrdemUtils> utilsStream = AppStream<OrdemUtils>.seed(
    OrdemUtils(),
  );
  OrdemUtils get utils => utilsStream.value;

  final AppStream<OrdemArquivadasUtils> utilsArquivadasStream =
      AppStream<OrdemArquivadasUtils>.seed(OrdemArquivadasUtils());
  OrdemArquivadasUtils get utilsArquivadas => utilsArquivadasStream.value;

  void onInit() {
    utilsStream.add(OrdemUtils());
    onReorder(FirestoreClient.ordens.ordensNaoCongeladas);
  }

  List<OrdemModel> getOrdensFiltered(String search, List<OrdemModel> ordens) {
    if (search.length < 3) return ordens;
    List<OrdemModel> filtered = [];
    for (final ordem in ordens) {
      if (ordem.localizator.toString().toCompare.contains(search.toCompare)) {
        filtered.add(ordem);
      }
    }
    return filtered;
  }

  final AppStream<OrdemCreateModel> formStream = AppStream<OrdemCreateModel>();
  OrdemCreateModel get form => formStream.value;

  void onInitCreatePage(OrdemModel? ordem) {
    try {
      formStream.add(
        ordem != null ? OrdemCreateModel.edit(ordem) : OrdemCreateModel(),
      );
    } catch (e) {
      log('Erro ao inicializar página de Ordem: $e');
      formStream.add(OrdemCreateModel());
    }
  }

  List<PedidoBitolaModel> getPedidosPorProduto(
    BitolaModel produto, {
    OrdemModel? ordem,
  }) {
    List<PedidoBitolaModel> pedidos = [
      ..._getPedidosProdutosAtual(ordem: ordem),
      ..._getPedidosProdutosSeparados(produto),
    ];
    // Guard extra: excluir produtos de pedidos Mestre (que possuem parciais)
    pedidos = pedidos.where((p) => p.pedido.pedidosFilhos.isEmpty).toList();
    onSortPedidos(pedidos);
    return pedidos;
  }

  List<PedidoBitolaModel> _getPedidosProdutosAtual({OrdemModel? ordem}) =>
      ordem != null
          ? ordem.produtos
              .map(
                (e) => e.copyWith(
                  isSelected: true,
                  isAvailable: e.isAvailableToChanges,
                ),
              )
              .toList()
          : [];

  List<PedidoBitolaModel> _getPedidosProdutosSeparados(BitolaModel produto) {
    List<PedidoBitolaModel> pedidos = [];
    for (final pedido in FirestoreClient.pedidos.data
        .where(
          (e) => e.pedidosFilhos.isEmpty && e.step.isPermiteProducao,
        )
        .toList()) {
      final pedidoProdutos = pedido.produtos
          .where(
            (e) =>
                e.status.status == PedidoBitolaStatus.separado &&
                e.produto.id == produto.id,
          )
          .toList();
      for (final pedidoProduto in pedidoProdutos) {
        final isFiltered = form.localizador.text.isEmpty ||
            pedidoProduto.pedido.localizador.toCompare.contains(
              form.localizador.text.toCompare,
            );
        if (isFiltered) {
          pedidos.add(pedidoProduto);
        }
      }
    }
    return pedidos;
  }

  List<PedidoBitolaModel> getPedidosPorProdutoEdit(OrdemModel ordem) {
    final pedidos = ordem.produtos
        .where(
          (e) =>
              form.localizador.text.isEmpty ||
              e.cliente.nome.toCompare.contains(
                form.localizador.text.toCompare,
              ),
        )
        .toList();
    onSortPedidos(pedidos);

    return pedidos;
  }

  Future<void> onConfirm(value, OrdemModel? ordem) async {
    try {
      if (form.isEdit) {
        await onEdit(value, ordem!);
      } else {
        await onCreate(value);
      }
    } catch (value) {
      NotificationService.showNegative(
        'Erro',
        value.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> onCreate(value) async {
    onValid();

    String bitola = form.produto!.descricao
        .replaceAll('mm', '')
        .replaceAll(',', '.')
        .split('.')
        .first
        .replaceAll(RegExp(r'[^0-9]'), '');

    final prefixo = 'OP$bitola-';
    final proximoSeq = await FirestoreClient.ordens.proximoSequencial(prefixo);
    form.id = '$prefixo${proximoSeq}_${HashService.get}';

    final ordemCriada = form.toOrdemModelCreate();
    if (ordemCriada.produtos.isEmpty) {
      if (!await showConfirmDialog(
        'Você está criando uma ordem vazia.',
        'Deseja Continuar?',
      )) {
        return;
      }
    }
    final List<(PedidoBitolaModel, PedidoBitolaStatus)> statusUpdates = [];
    final List<(PedidoBitolaModel, MateriaPrimaModel?)> mpUpdates = [];
    final Set<String> pedidosAfetados = {};

    for (PedidoBitolaModel produto in ordemCriada.produtos) {
      statusUpdates.add((produto, PedidoBitolaStatus.aguardandoProducao));
      pedidosAfetados.add(produto.pedidoId);

      if (ordemCriada.materiaPrima != null) {
        mpUpdates.add((produto, ordemCriada.materiaPrima!));
        produto.materiaPrima = ordemCriada.materiaPrima;
      }

      if (produto.statusess.isEmpty ||
          produto.statusess.last.status !=
              PedidoBitolaStatus.aguardandoProducao) {
        produto.statusess.add(PedidoBitolaStatusModel.create(
            PedidoBitolaStatus.aguardandoProducao));
      }
    }

    if (FirestoreClient.pedidos is PedidoSupabaseCollection) {
      final supabaseColl = FirestoreClient.pedidos as PedidoSupabaseCollection;
      await Future.wait([
        if (mpUpdates.isNotEmpty) supabaseColl.updateProdutosMateriaPrima(mpUpdates),
        if (statusUpdates.isNotEmpty) supabaseColl.updateProdutosStatus(statusUpdates),
      ]);
    } else {
      for (var update in mpUpdates) {
        await FirestoreClient.pedidos
            .updateProdutoMateriaPrima(update.$1, update.$2);
      }
      for (var update in statusUpdates) {
        await FirestoreClient.pedidos.updateProdutoStatus(update.$1, update.$2);
      }
    }

    await FirestoreClient.ordens.add(ordemCriada);

    await Future.wait(pedidosAfetados.map((pedidoId) async {
      final pedido = FirestoreClient.pedidos.getById(pedidoId);
      if (pedido.produtos.isNotEmpty) {
        await FirestoreClient.pedidos.updatePedidoStatus(pedido.produtos.first);
      }
    }));

    await Future.wait([
      FirestoreClient.ordens.fetch(),
      FirestoreClient.pedidos.fetch(),
    ]);
    onReorder(FirestoreClient.ordens.ordensNaoCongeladas);
    // Automação em background — catchError garante que falhas não sejam silenciosas
    unawaited(automatizacaoCtrl.onSetStepByPedidoStatus(
      ordemCriada.pedidos
          .map<PedidoModel>((e) => BackendClient.pedidos.getById(e.id))
          .toList(),
    ).catchError((e) => log('[Automação] Erro ao criar ordem: $e')));

    Navigator.pop(value);
    NotificationService.showPositive(
      'Ordem Adicionada',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );

    // Audit
    AuditService.registrar(
      acao: 'criar_ordem',
      modulo: 'ordem',
      entidadeId: ordemCriada.id,
      entidadeLabel: ordemCriada.localizator,
      detalhes: {'produtos': ordemCriada.produtos.length},
    );
  }

  Future<void> onEdit(value, OrdemModel ordem) async {
    onValid();
    final ordemEditada = form.toOrdemModelEdit(ordem);
    if (ordemEditada.produtos.isEmpty) {
      if (!await showConfirmDialog('A ordem vazia.', 'Deseja Continuar?')) {
        return;
      }
    }

    final List<(PedidoBitolaModel, PedidoBitolaStatus)> statusUpdates = [];
    final List<(PedidoBitolaModel, MateriaPrimaModel?)> mpUpdates = [];
    final Set<String> pedidosAfetados = {};

    for (PedidoBitolaModel produto in ordem.produtos) {
      if (!ordemEditada.produtos.any((e) => e.id == produto.id)) {
        statusUpdates.add((produto, PedidoBitolaStatus.separado));
        pedidosAfetados.add(produto.pedidoId);
        if (produto.materiaPrima != null) {
          mpUpdates.add((produto, null));
        }
      }
    }

    for (PedidoBitolaModel produto in ordemEditada.produtos) {
      pedidosAfetados.add(produto.pedidoId);

      if (produto.status.status != PedidoBitolaStatus.pronto) {
        if (ordemEditada.materiaPrima?.id != produto.materiaPrima?.id) {
          mpUpdates.add((produto, ordemEditada.materiaPrima!));
        }
      }

      PedidoBitolaStatus newStatus = produto.status.status;
      if (newStatus == PedidoBitolaStatus.separado) {
        newStatus = PedidoBitolaStatus.aguardandoProducao;
        produto.statusess.add(PedidoBitolaStatusModel.create(newStatus));
      }
      statusUpdates.add((produto, newStatus));
    }

    if (FirestoreClient.pedidos is PedidoSupabaseCollection) {
      final supabaseColl = FirestoreClient.pedidos as PedidoSupabaseCollection;
      await Future.wait([
        if (mpUpdates.isNotEmpty) supabaseColl.updateProdutosMateriaPrima(mpUpdates),
        if (statusUpdates.isNotEmpty) supabaseColl.updateProdutosStatus(statusUpdates),
      ]);
    } else {
      for (var update in mpUpdates) {
        await FirestoreClient.pedidos
            .updateProdutoMateriaPrima(update.$1, update.$2);
      }
      for (var update in statusUpdates) {
        await FirestoreClient.pedidos.updateProdutoStatus(update.$1, update.$2);
      }
    }

    await FirestoreClient.ordens.update(ordemEditada);

    await Future.wait(pedidosAfetados.map((pedidoId) async {
      final pedido = FirestoreClient.pedidos.getById(pedidoId);
      if (pedido.produtos.isNotEmpty) {
        await FirestoreClient.pedidos.updatePedidoStatus(pedido.produtos.first);
      }
    }));

    await Future.wait([
      FirestoreClient.ordens.fetch(),
      FirestoreClient.pedidos.fetch(),
      OrdemTimelineRegister.editada(ordemEditada, ordem),
    ]);
    // Automação em background — busca instâncias atualizadas do backend (evita stale)
    unawaited(automatizacaoCtrl.onSetStepByPedidoStatus(
      ordemEditada.pedidos
          .map<PedidoModel>((e) => BackendClient.pedidos.getById(e.id))
          .toList(),
    ).catchError((e) => log('[Automação] Erro ao editar ordem: $e')));

    Navigator.pop(value);
    Navigator.pop(value);
    NotificationService.showPositive(
      'Ordem Editada',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );

    // Audit
    AuditService.registrar(
      acao: 'editar_ordem',
      modulo: 'ordem',
      entidadeId: ordemEditada.id,
      entidadeLabel: ordemEditada.localizator,
    );
  }

  void onValid() {
    if (form.produto == null) {
      throw Exception('Selecione o produto');
    }
    if (form.materiaPrima == null) {
      throw Exception('Selecione a matéria prima');
    }
    if (form.equipamento == null) {
      throw Exception('Selecione o equipamento');
    }
  }

  Future<void> onDelete(value, OrdemModel ordem) async {
    // Verificar se a ordem possui plano de corte executado
    try {
      final planosExecutados = await SupabaseService.client
          .from('planos_corte')
          .select('id')
          .eq('ordem_id', ordem.id)
          .eq('status', 'executado');
      if (planosExecutados.isNotEmpty) {
        NotificationService.showNegative(
          'Ordem protegida',
          'Esta ordem possui um plano de corte executado. Cancele a execução do plano antes de excluir a ordem.',
          position: NotificationPosition.bottom,
        );
        return;
      }
    } catch (_) {}

    if (await _isDeleteUnavailable(ordem)) return;

    // Coleta todos os pedidos afetados e atualiza em paralelo
    final pedidosProdutos = ordem.produtos
        .map<PedidoBitolaModel>(
          (e) => FirestoreClient.pedidos.getProdutoByPedidoId(
            e.pedidoId,
            e.id,
          ),
        )
        .toList();

    // Persiste status 'separado' direto na tabela pedido_bitolas
    // (não usa update(pedido) genérico para evitar bug de instâncias divergentes)
    final statusUpdates = pedidosProdutos
        .map((pp) => (pp, PedidoBitolaStatus.separado))
        .toList();
    if (FirestoreClient.pedidos is PedidoSupabaseCollection) {
      await (FirestoreClient.pedidos as PedidoSupabaseCollection)
          .updateProdutosStatus(statusUpdates, clear: true);
    } else {
      for (var update in statusUpdates) {
        await FirestoreClient.pedidos
            .updateProdutoStatus(update.$1, update.$2);
      }
    }

    // Atualiza status do pedido pai para cada pedido afetado
    final pedidosAfetados = pedidosProdutos.map((pp) => pp.pedidoId).toSet();
    await Future.wait(pedidosAfetados.map((pedidoId) async {
      final pedido = FirestoreClient.pedidos.getById(pedidoId);
      if (pedido.produtos.isNotEmpty) {
        await FirestoreClient.pedidos
            .updatePedidoStatus(pedido.produtos.first);
      }
    }));

    ordem.produtos.clear();
    await FirestoreClient.ordens.delete(ordem);
    // ordens.fetch() removido — Realtime já cuida
    // Automação em background — busca instâncias atualizadas do backend (evita stale)
    unawaited(automatizacaoCtrl.onSetStepByPedidoStatus(
      ordem.pedidos
          .map<PedidoModel>((e) => BackendClient.pedidos.getById(e.id))
          .toList(),
    ).catchError((e) => log('[Automação] Erro ao excluir ordem: $e')));
    pop(value);

    onReorder(FirestoreClient.ordens.ordensNaoCongeladas);

    NotificationService.showPositive(
      'Ordem Excluida',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );

    // Audit
    AuditService.registrar(
      acao: 'excluir_ordem',
      modulo: 'ordem',
      entidadeId: ordem.id,
      entidadeLabel: ordem.localizator,
    );
  }

  Future<bool> _isDeleteUnavailable(OrdemModel ordem) async =>
      !await onDeleteProcess(
        deleteTitle: 'Deseja excluir a ordem?',
        deleteMessage: 'Todos seus dados da ordem apagados do sistema',
        infoMessage: 'Remova os produtos da ordem para poder excluir-la.',
        conditional: ordem.produtos.isNotEmpty,
      );

  void onSortPedidos(List<PedidoBitolaModel> pedidos) {
    bool isAsc = form.sortOrder == SortOrder.asc;
    switch (form.sortType) {
      case SortType.localizator:
        pedidos.sort(
          (a, b) => isAsc
              ? a.pedido.localizador.compareTo(b.pedido.localizador)
              : b.pedido.localizador.compareTo(a.pedido.localizador),
        );
        break;
      case SortType.alfabetic:
        pedidos.sort(
          (a, b) => isAsc
              ? a.pedido.localizador.compareTo(b.pedido.localizador)
              : b.pedido.localizador.compareTo(a.pedido.localizador),
        );
        break;
      case SortType.deliveryAt:
        pedidos.sort((a, b) {
          final aDelivery = a.pedido.deliveryAt;
          final bDelivery = b.pedido.deliveryAt;
          if (aDelivery == null && bDelivery == null) return 0;
          if (aDelivery == null) return 1;
          if (bDelivery == null) return -1;
          return isAsc
              ? aDelivery.compareTo(bDelivery)
              : bDelivery.compareTo(aDelivery);
        });
      case SortType.createdAt:
        pedidos.sort(
          (a, b) => isAsc
              ? a.pedido.createdAt.compareTo(b.pedido.createdAt)
              : b.pedido.createdAt.compareTo(a.pedido.createdAt),
        );
        break;
      case SortType.qtde:
        pedidos.sort(
          (a, b) => isAsc ? a.qtde.compareTo(b.qtde) : b.qtde.compareTo(a.qtde),
        );
      case SortType.client:
        pedidos.sort(
          (a, b) => isAsc
              ? a.pedido.cliente.nome.compareTo(b.pedido.cliente.nome)
              : b.pedido.cliente.nome.compareTo(a.pedido.cliente.nome),
        );
        break;
    }
  }

  //ORDEM
  final AppStream<OrdemModel> ordemStream = AppStream<OrdemModel>();
  OrdemModel get ordem => ordemStream.value;

  StreamSubscription<OrdemModel>? subscription;
  void onInitPage(String ordemId, {OrdemModel? ordem}) {
    try {
      final initialOrdem = ordem ?? getOrdemById(ordemId);
      ordemStream.add(initialOrdem);

      // Re-lê config de apontamento para garantir valor atualizado
      PreferencesService.refreshApontamentoCD();

      // Carrega os pedidos da ordem para garantir que os produtos (bitolas) apareçam
      _fetchPedidosDaOrdem(initialOrdem);

      subscription =
          FirestoreClient.ordens.listenById(ordemId).listen((ordemFetched) {
        // Agora aceita que a lista de produtos seja esvaziada (permitido pela UI).
        ordemStream.add(ordemFetched);
        _fetchPedidosDaOrdem(ordemFetched);
      });
    } catch (e) {
      log('Erro ao inicializar detalhes da ordem: $e');
      ordemStream.add(OrdemModel.empty());
    }
  }

  Future<void> _fetchPedidosDaOrdem(OrdemModel ordem) async {
    if (ordem.id.isEmpty) return;
    final pedidoIds = ordem.idPedidosProdutosRefs
        .map((e) => e['pedidoId'] ?? e['pedido_id'] ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (pedidoIds.isNotEmpty) {
      // Busca os pedidos no banco para popular a memória local e as bitolas aparecerem
      await FirestoreClient.pedidos.fetchByIds(pedidoIds);
      ordemStream
          .update(); // Força a re-renderização com os produtos agora carregados
    }
  }

  void onDisposePage() {
    subscription?.cancel();
    subscription = null;
  }

  OrdemModel getOrdemById(String ordemId) {
    try {
      final ordem =
          FirestoreClient.ordens.data.firstWhereOrNull((e) => e.id == ordemId);
      return ordem ?? OrdemModel.empty();
    } catch (_) {
      return OrdemModel.empty();
    }
  }

  void setOrdem(OrdemModel ordem) {
    ordemStream.add(ordem);
  }

  void showBottomChangeProdutosStatus(List<PedidoBitolaModel> produtos) async {
    final status = await showOrdemProdutosStatusBottom();
    if (status == null) return;
    if (!await showConfirmDialog(
      'Mover alterar status de todos os produtos?',
      'Todos os produtos serão alterados para ${status.label}.\nEsta ação pode demorar um pouco.',
    )) {
      return;
    }
    showLoadingDialog();
    for (final produto
        in produtos.where((e) => e.status.status != status).toList()) {
      await onChangeProdutoStatus(produto, status, true);
    }
    await OrdemTimelineRegister.statusProdutoAlterada(
      ordem,
      OrdemStatusProdutos(status: status, produtos: produtos),
    );
    final updatedOrdem = getOrdemById(ordem.id);
    if (updatedOrdem.status != ordem.status) {
      await OrdemTimelineRegister.statusOrdem(updatedOrdem);
    }
    if (contextGlobal.mounted) Navigator.pop(contextGlobal);
    onReorder(FirestoreClient.ordens.ordensNaoCongeladas);
    onUpdateAt(ordem);
  }

  void showBottomChangeProdutoStatus(
    OrdemModel ordem,
    PedidoBitolaModel produto,
  ) async {
    final produtoStatus = produto.statusess.last.status;
    final status = await showOrdemProdutoStatusBottom(produtoStatus);
    if (status == null || produtoStatus == status) return;
    // Busca o produto atualizado no cache para garantir que a matéria prima está populada
    final produtoAtualizado = FirestoreClient.pedidos
        .getProdutoByPedidoId(produto.pedidoId, produto.id);
    final materiaPrimaEfetiva =
        produtoAtualizado.materiaPrima ?? produto.materiaPrima;
    if ((status == PedidoBitolaStatus.pronto ||
            status == PedidoBitolaStatus.produzindo) &&
        materiaPrimaEfetiva == null) {
      showInfoDialog(
        'Para finalizar a ordem, é necessário selecionar uma matéria prima para o produto.',
      );
      return;
    }

    await onChangeProdutoStatus(produto, status, false);
    onReorder(FirestoreClient.ordens.ordensNaoCongeladas);
    onUpdateAt(ordem);
  }

  Future<void> onSelectProdutoStatus(
    OrdemModel ordem,
    PedidoBitolaModel produto,
    PedidoBitolaStatus status,
  ) async {
    // Busca o produto atualizado no cache para garantir que a matéria prima está populada
    final produtoAtualizado = FirestoreClient.pedidos
        .getProdutoByPedidoId(produto.pedidoId, produto.id);
    final materiaPrimaEfetiva =
        produtoAtualizado.materiaPrima ?? produto.materiaPrima;
    if ((status == PedidoBitolaStatus.pronto ||
            status == PedidoBitolaStatus.produzindo) &&
        materiaPrimaEfetiva == null) {
      showInfoDialog(
        'Para finalizar a ordem, é necessário selecionar uma matéria prima para o produto.',
      );
      return;
    }
    if (status == PedidoBitolaStatus.produzindo) {
      if (ordem.produtos.any(
        (e) => e.status.status == PedidoBitolaStatus.produzindo && !e.isPaused,
      )) {
        showInfoDialog(
          'Não é possível produzir mais de um produto ao mesmo tempo.',
        );
        return;
      }
    }
    showLoadingDialog();
    await onChangeProdutoStatus(produto, status, false);
    onReorder(FirestoreClient.ordens.ordensNaoCongeladas);
    onUpdateAt(ordem);
    if (contextGlobal.mounted) Navigator.pop(contextGlobal);
  }

  Future<void> onChangeProdutoStatus(
    PedidoBitolaModel produto,
    PedidoBitolaStatus status,
    bool isAll,
  ) async {
    if (status == PedidoBitolaStatus.aguardandoProducao) {
      final materiaPrima = FirestoreClient.materiaPrimas.data.firstWhereOrNull(
        (e) => e.id == produto.materiaPrima?.id,
      );
      if (materiaPrima != null &&
          materiaPrima.status == MateriaPrimaStatus.finalizada) {
        if (!await showConfirmDialog(
          'A matéria prima ${materiaPrima.corridaLote} está finalizada, lembre-se que deve alterar a matéria prima para produzir novamente.',
          'Deseja continuar?',
        )) {
          return;
        }
      }
    }
    final statusAnterior = produto.status.status;

    await FirestoreClient.pedidos.updateProdutoStatus(produto, status);
    final pedido = await FirestoreClient.pedidos.updatePedidoStatus(produto);
    if (pedido != null) await updateFeaturesByPedidoStatus(pedido);

    // Baixa automática de estoque quando produto fica pronto
    if (status == PedidoBitolaStatus.pronto) {
      // Proteção contra baixa dupla: se posições (modo por_os) já
      // geraram baixas individuais, desconta o peso já baixado.
      final progresso = calcularProgressoPosicoes(
        produto.pedidoId,
        produto.produto.id,
      );
      final pesoJaBaixado = progresso.hasData ? progresso.pesoPronto : 0.0;
      final qtdeBaixar = (produto.qtde - pesoJaBaixado).clamp(0.0, produto.qtde);

      if (qtdeBaixar > 0) {
        await estoqueCtrl.baixarEstoque(
          produtoId: produto.produto.id,
          quantidade: qtdeBaixar,
          ordem: ordem,
        );
      }
    }

    // Estorno quando produto volta de PRONTO para outro status
    if (statusAnterior == PedidoBitolaStatus.pronto &&
        status != PedidoBitolaStatus.pronto) {
      // Mesma proteção: estorna apenas o que foi baixado neste nível,
      // sem estornar o que já foi baixado pelas posições (será
      // estornado individualmente ao voltar cada posição).
      final progresso = calcularProgressoPosicoes(
        produto.pedidoId,
        produto.produto.id,
      );
      final pesoJaBaixado = progresso.hasData ? progresso.pesoPronto : 0.0;
      final qtdeEstornar = (produto.qtde - pesoJaBaixado).clamp(0.0, produto.qtde);

      if (qtdeEstornar > 0) {
        await estoqueCtrl.estornarBaixa(
          produtoId: produto.produto.id,
          quantidade: qtdeEstornar,
          ordem: ordem,
        );
      }
    }

    // Sincroniza posições dos elementos quando no modo "por_pedido"
    await _syncPosicoesByPedidoStatus(produto, status);

    if (!isAll) {
      await OrdemTimelineRegister.statusProdutoAlterada(
        ordem,
        OrdemStatusProdutos(status: status, produtos: [produto]),
      );
    }
    // fetch em background com delay: aguarda propagação do Firestore antes de
    // re-buscar ordens. Sem o delay, o fetch pode trazer dados desatualizados
    // (status antigo do pedido) e causar flicker na UI (aguardando→produzindo→aguardando→produzindo).
    unawaited(Future.delayed(const Duration(seconds: 3), () => FirestoreClient.ordens.fetch()));
    final updatedOrdem = getOrdemById(ordem.id);
    if (!isAll && updatedOrdem.status != ordem.status) {
      unawaited(OrdemTimelineRegister.statusOrdem(updatedOrdem));
    }
    setOrdem(updatedOrdem);
  }

  /// Sincroniza todas as posições de um pedido com o status do card.
  /// Chamado quando o operador muda status no modo "por_pedido".
  Future<void> _syncPosicoesByPedidoStatus(
    PedidoBitolaModel produto,
    PedidoBitolaStatus pedidoStatus,
  ) async {
    // Converte PedidoBitolaStatus para PosicaoStatus
    final PosicaoStatus? posicaoStatusRaw;
    switch (pedidoStatus) {
      case PedidoBitolaStatus.aguardandoProducao:
        posicaoStatusRaw = PosicaoStatus.aguardando;
        break;
      case PedidoBitolaStatus.produzindo:
        posicaoStatusRaw = PosicaoStatus.produzindo;
        break;
      case PedidoBitolaStatus.pronto:
        posicaoStatusRaw = PosicaoStatus.pronto;
        break;
      default:
        posicaoStatusRaw = null;
    }
    if (posicaoStatusRaw == null) return;
    final PosicaoStatus posicaoStatus = posicaoStatusRaw;

    // Busca elementos do pedido — se cache vazio, busca do Supabase
    var elementos = AppSupabaseClient.elementos.data
        .where((e) => e.pedidoId == produto.pedidoId)
        .toList();
    if (elementos.isEmpty) {
      try {
        log('_syncPosicoes: cache vazio para pedido ${produto.pedidoId}, buscando do Supabase...');
        await AppSupabaseClient.elementos.fetchByPedidoId(produto.pedidoId);
        elementos = AppSupabaseClient.elementos.data
            .where((e) => e.pedidoId == produto.pedidoId)
            .toList();
      } catch (e) {
        log('_syncPosicoes: erro ao buscar elementos do Supabase: $e');
      }
    }
    if (elementos.isEmpty) return;

    // Busca a bitola da ordem para filtrar posições
    final bitolaId = ordem.produto.id;

    // Coleta IDs das posições que precisam ser atualizadas
    final List<String> idsToUpdate = [];
    for (final elemento in elementos) {
      for (final posicao in elemento.posicoes) {
        if (posicao.produtoId == bitolaId && posicao.status != posicaoStatus) {
          idsToUpdate.add(posicao.id);
          // Atualiza cache local
          posicao.status = posicaoStatus;
        }
      }
    }

    if (idsToUpdate.isNotEmpty) {
      // Persiste no Supabase em paralelo (batch) com tratamento de erro
      try {
        await Future.wait(
          idsToUpdate.map((id) => SupabaseService.client
              .from('elemento_posicoes')
              .update({'status': posicaoStatus.name}).eq('id', id)),
        );
      } catch (e) {
        log('_syncPosicoes: ERRO ao persistir ${idsToUpdate.length} posições para ${posicaoStatus.name}: $e');
        // Retry: tenta novamente sequencialmente as que falharam
        for (final id in idsToUpdate) {
          try {
            await SupabaseService.client
                .from('elemento_posicoes')
                .update({'status': posicaoStatus.name}).eq('id', id);
          } catch (retryError) {
            log('_syncPosicoes: FALHA no retry da posição $id: $retryError');
          }
        }
      }
      // Re-emite stream de elementos
      AppSupabaseClient.elementos.dataStream
          .add(AppSupabaseClient.elementos.data);
    }
  }

  Future<void> updateFeaturesByPedidoStatus(PedidoModel pedido) async {
    await automatizacaoCtrl.onSetStepByPedidoStatus([pedido]);
    pedidoCtrl.onAddHistory(
      pedido: pedido,
      data: pedido.statusess.last,
      action: PedidoHistoryAction.update,
      type: PedidoHistoryType.status,
    );
  }

  Future<void> onFreezed(value, OrdemModel ordem) async {
    if (ordem.freezed.isFreezed) {
      if (!await showConfirmDialog(
        'Deseja descongelar a ordem?',
        'A ordem voltará na ultima posição da esteira de produção.',
      )) {
        return;
      }
      ordem.freezed.isFreezed = false;
      ordem.freezed.reason.controller.clear();
      await OrdemTimelineRegister.descongelada(ordem);
    } else {
      if (!await showConfirmDialog(
        'Deseja congelar a ordem?',
        'A ordem irá sair da esteira de produção.',
      )) {
        return;
      }
      ordem.freezed.isFreezed = true;
      await OrdemTimelineRegister.congelada(ordem);
    }
    await FirestoreClient.ordens.update(ordem);
    onReorder(FirestoreClient.ordens.ordensNaoCongeladas);
    Navigator.pop(value);
    if (ordem.freezed.isFreezed) {
      NotificationService.showPositive(
        'Ordem ${ordem.localizator} congelada!',
        'Ordem foi removida da esteira de produção',
      );
    } else {
      NotificationService.showPositive(
        'Ordem ${ordem.localizator} descongelada!',
        'Ordem foi adicionada na ultima posição esteira de produção',
      );
    }

    // Audit
    AuditService.registrar(
      acao: ordem.freezed.isFreezed ? 'congelar_ordem' : 'descongelar_ordem',
      modulo: 'ordem',
      entidadeId: ordem.id,
      entidadeLabel: ordem.localizator,
    );
  }

  void onReorder(List<OrdemModel> ordensNaoConcluidas) {
    for (var i = 0; i < ordensNaoConcluidas.length; i++) {
      ordensNaoConcluidas[i].beltIndex = i;
    }
    // Re-ordena a lista do stream por beltIndex e re-emite
    final lista = FirestoreClient.ordens.ordensNaoArquivadasStream.value;
    lista.sort((a, b) {
      if (a.freezed.isFreezed && !b.freezed.isFreezed) return 1;
      if (!a.freezed.isFreezed && b.freezed.isFreezed) return -1;
      if (a.beltIndex == null || b.beltIndex == null) return 0;
      return a.beltIndex!.compareTo(b.beltIndex!);
    });
    FirestoreClient.ordens.ordensNaoArquivadasStream.add(lista);
    FirestoreClient.ordens.dataStream.add(lista);

    // Persiste no banco bloqueando o Realtime durante o batch
    if (FirestoreClient.ordens is OrdemSupabaseCollection) {
      final supabaseColl = FirestoreClient.ordens as OrdemSupabaseCollection;
      supabaseColl.reorderAll(ordensNaoConcluidas);
    } else {
      for (var ordem in ordensNaoConcluidas) {
        FirestoreClient.ordens.update(ordem);
      }
    }
  }

  Future<void> onGenerateRelatorioPDF(OrdemModel ordem) async {
    final RelatorioOrdemViewModel relatorio = RelatorioOrdemViewModel();
    relatorio.ordem = ordem;
    relatorio.type = RelatorioOrdemType.ORDEM;
    relatorio.relatorio = RelatorioOrdemModel.ordem(ordem);

    relatorioCtrl.ordemViewModelStream.add(relatorio);

    await relatorioCtrl.onExportRelatorioOrdemUniquePDF(
      RelatorioOrdemModel.ordem(ordem),
    );
  }

  Future<void> onGenerateEtiquetasPDF(OrdemModel ordem) async {
    List<OrdemEtiquetaModel> model = [];
    for (var produto in ordem.produtos) {
      model.add(
        OrdemEtiquetaModel(
          cliente: produto.pedido.cliente,
          obra: produto.pedido.obra,
          pedido: produto.pedido,
          ordem: ordem.copyWith(produtos: [produto.copyWith()]),
          createdAt: DateTime.now(),
          produto: produto,
        ),
      );
    }

    final pdf = pw.Document();

    final imageBytes = await LogoHelper.logoBytesForPdf();

    pdf.addPage(OrdemEtiquetasPdfPage(model).build(imageBytes));

    final name =
        "m2_etiquetas_ordem_${ordem.localizator.toLowerCase()}_${DateTime.now().toFileName()}.pdf";

    await downloadPDF(name, '/ordem/etiquetas/', await pdf.save());
  }

  Future<void> onArchive(BuildContext context, OrdemModel ordem) async {
    if (await _isArchiveUnavailable(ordem)) return;
    ordem.isArchived = true;
    showLoadingDialog();
    await FirestoreClient.ordens.update(ordem);
    await FirestoreClient.ordens.fetch();
    await OrdemTimelineRegister.arquivada(ordem);
    await FirestoreClient.ordens.startOnlyArquivadas();
    onReorder(FirestoreClient.ordens.ordensNaoCongeladas);
    if (contextGlobal.mounted) Navigator.pop(contextGlobal);
    if (context.mounted) Navigator.pop(context);
    NotificationService.showPositive(
      'Ordem Arquivada!',
      'Acesse a lista de ordens arquivadas para visualizar a ordem',
    );

    // Audit
    AuditService.registrar(
      acao: 'arquivar_ordem',
      modulo: 'ordem',
      entidadeId: ordem.id,
      entidadeLabel: ordem.localizator,
    );
  }

  Future<bool> _isArchiveUnavailable(
    OrdemModel ordem,
  ) async =>
      !await onDeleteProcess(
        deleteTitle: 'Deseja arquivar a ordem?',
        deleteMessage: 'A ordem será movida para a lista de ordens arquivadas.',
        infoMessage:
            'A ordem só pode ser arquivada se todos os produtos estiverem prontos.',
        conditional: ordem.status != PedidoBitolaStatus.pronto,
      );

  Future<void> onUnarchive(
    BuildContext context,
    OrdemModel ordem,
    int pop,
  ) async {
    ordem.isArchived = false;
    showLoadingDialog();
    await FirestoreClient.ordens.update(ordem);
    await FirestoreClient.ordens.fetch();
    await FirestoreClient.ordens.startOnlyArquivadas();
    if (contextGlobal.mounted) Navigator.pop(contextGlobal);
    for (var i = 0; i < pop; i++) {
      if (context.mounted) Navigator.pop(context);
    }
    await OrdemTimelineRegister.desarquivada(ordem);
    NotificationService.showPositive(
      'Ordem Desarquivada!',
      'Acesse a lista de ordens para visualizar a ordem',
    );

    // Audit
    AuditService.registrar(
      acao: 'desarquivar_ordem',
      modulo: 'ordem',
      entidadeId: ordem.id,
      entidadeLabel: ordem.localizator,
    );
  }

  Future<void> onUpdateAt(OrdemModel ordem) async {
    ordem.updatedAt = DateTime.now();
    await FirestoreClient.ordens.update(ordem);
  }

  MateriaPrimaModel? getMateriaPrimaByPedidoProduto(
    List<PedidoModel> pedidos,
    PedidoBitolaModel produto,
  ) {
    MateriaPrimaModel? materiaPrima;
    for (var pedido in pedidos) {
      if (pedido.id == produto.pedidoId) {
        materiaPrima = pedido.produtos
            .firstWhereOrNull((e) => e.id == produto.id)
            ?.materiaPrima;
      }
    }
    return materiaPrima;
  }

  Future<void> onPauseProduto(
    OrdemModel ordem,
    PedidoBitolaModel produto,
  ) async {
    final motivo = await showOrdemPedidoProdutoPauseMotivoBottom();
    if (motivo == null) return;
    showLoadingDialog();
    produto.isPaused = true;
    await FirestoreClient.pedidos.updateProdutoPause(produto, true);
    await OrdemTimelineRegister.produtoPausado(ordem, produto, motivo);
    await FirestoreClient.pedidos.fetch();
    await FirestoreClient.ordens.fetch();
    Navigator.pop(contextGlobal);
  }

  Future<void> onUnpauseProduto(
    OrdemModel ordem,
    PedidoBitolaModel produto,
  ) async {
    showLoadingDialog();
    produto.isPaused = false;
    await FirestoreClient.pedidos.updateProdutoPause(produto, false);
    await OrdemTimelineRegister.produtoDespausado(ordem, produto);
    await FirestoreClient.pedidos.fetch();
    await FirestoreClient.ordens.fetch();
    Navigator.pop(contextGlobal);
  }
}
