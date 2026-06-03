import 'dart:async';
import 'dart:developer';

import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/automatizacao_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/cliente/cliente_supabase_collection.dart';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';


import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/archive/archive_model.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/enums/sort_type.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/automatizacao/automatizacao_controller.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_status_bottom.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_step_bottom.dart';

import 'package:aco_plus/app/modules/pedido/view_models/pedido_bitola_view_model.dart';
import 'package:aco_plus/app/modules/pedido/view_models/pedido_view_model.dart';
import 'package:aco_plus/app/modules/relatorio/relatorio_controller.dart';
import 'package:aco_plus/app/modules/relatorio/ui/pedido/relatorio_pedido_pdf_page.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:overlay_support/overlay_support.dart';

final pedidoCtrl = PedidoController();
PedidoModel get pedido => pedidoCtrl.pedido;

class PedidoController {
  static final PedidoController _instance = PedidoController._();

  PedidoController._();

  factory PedidoController() => _instance;

  final AppStream<int> activeTabStream = AppStream<int>.seed(0);


  final AppStream<PedidoUtils> utilsStream = AppStream<PedidoUtils>.seed(
    PedidoUtils(),
  );
  PedidoUtils get utils => utilsStream.value;

  final AppStream<PedidoArquivedUtils> utilsArquivedsStream =
      AppStream<PedidoArquivedUtils>.seed(PedidoArquivedUtils());
  PedidoArquivedUtils get utilsArquiveds => utilsArquivedsStream.value;

  void onInit() {
    try {
      utilsStream.add(PedidoUtils());
      BackendClient.pedidos.fetch();
      _listenChecklists();
      _listenGlobalPedidos();
    } catch (e) {
      log('PedidoController: Erro no onInit', error: e);
    }
  }

  Timer? _pagePollingTimer;
  void onInitPage(PedidoModel pedido) {
    // Bloqueia o _listenGlobalPedidos por 5s para evitar race condition
    // (evita que um fetch concorrente sobrescreva o pedido que estamos abrindo)
    _ultimaGravacaoLocal = DateTime.now();
    activeTabStream.add(0); // reseta a aba ativa ao abrir um novo pedido
    pedidoStream.add(pedido);
    // Forçar atualização das ordens para garantir que vínculos editados recentemente sejam refletidos
    FirestoreClient.ordens.fetch();
    FirestoreClient.ordens.startOnlyArquivadas();
    _pagePollingTimer?.cancel();

    // Primeira atualização rápida após 1 segundo da abertura
    Future.delayed(const Duration(seconds: 1), () async {
      if (pedidoStream.hasValue) {
        // Verifica ANTES do await
        if (_estaProtegido()) return;

        final updated =
            await BackendClient.pedidos.getByIdSupabase(pedidoStream.value.id);

        // Verifica DEPOIS do await também — o usuário pode ter editado durante a busca
        if (_estaProtegido()) return;

        if (updated != null) {
          await BackendClient.ordens.fetch();
          await BackendClient.ordens.startOnlyArquivadas();
          pedidoStream.add(updated);
          SchedulerBinding.instance.scheduleFrame();
        }
      }
    });

    // Manutenção periódica a cada 3 segundos
    _pagePollingTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (pedidoStream.hasValue) {
        // Verifica ANTES do await
        if (_estaProtegido()) return;

        final updated =
            await BackendClient.pedidos.getByIdSupabase(pedidoStream.value.id);

        // Verifica DEPOIS do await também — o usuário pode ter editado durante a busca
        if (_estaProtegido()) return;

        if (updated != null) {
          // Só atualiza se houver mudança real
          final current = pedidoStream.value;
          final hasChanged = updated.localizador != current.localizador ||
              updated.statusess.length != current.statusess.length ||
              updated.steps.length != current.steps.length ||
              updated.comments.length != current.comments.length ||
              updated.histories.length != current.histories.length ||
              updated.deliveryAt != current.deliveryAt ||
              updated.isArchived != current.isArchived;

          if (hasChanged) {
            await BackendClient.ordens.fetch();
            await BackendClient.ordens.startOnlyArquivadas();
            pedidoStream.add(updated);
            SchedulerBinding.instance.scheduleFrame();
          }
        }
      }
    });
  }

  /// Retorna true se houve gravação local recente (< 5s).
  /// Usado para bloquear atualizações vindas do servidor que poderiam
  /// sobrescrever dados que o usuário acabou de editar.
  bool _estaProtegido() {
    if (_ultimaGravacaoLocal == null) return false;
    return DateTime.now().difference(_ultimaGravacaoLocal!).inSeconds < 5;
  }

  void onDisposePage() {
    _pagePollingTimer?.cancel();
    _pagePollingTimer = null;
  }

  void _listenGlobalPedidos() {
    BackendClient.pedidos.dataStream.listen.listen((pedidos) {
      if (pedidoStream.hasValue) {
        // Não sobrescreve se houve gravação local recente (< 5s)
        // evita que o Realtime apague tags/campos editados antes do banco confirmar
        if (_estaProtegido()) return;

        final currentId = pedidoStream.value.id;
        final updatedPedido =
            pedidos.firstWhereOrNull((e) => e.id == currentId);
        if (updatedPedido != null) {
          pedidoStream.add(updatedPedido);
          SchedulerBinding.instance.scheduleFrame();
        }
      }
    });

    // Quando ordens mudam (add/edit/remove), o número da ordem e a matéria-prima
    // exibidos no pedido precisam ser recalculados.
    // getOrdemByProduto lê FirestoreClient.ordens.data em memória — precisamos de rebuild.
    FirestoreClient.ordens.dataStream.listen.listen((_) {
      if (pedidoStream.hasValue) {
        pedidoStream.update();
        SchedulerBinding.instance.scheduleFrame();
      }
    });
  }

  void _listenChecklists() {
    BackendClient.checklists.dataStream.listen.listen((checklists) {
      if (formStream.hasValue && form.checklist == null) {
        form.checklist = checklists.firstWhereOrNull(
          (e) => e.isPadrao,
        );
        formStream.update();
      }
    });
  }

  final AppStream<PedidoCreateModel> formStream =
      AppStream<PedidoCreateModel>();
  PedidoCreateModel get form => formStream.value;

  void onInitCreatePage(PedidoModel? pedido, PedidoModel? pai) {
    formStream.add(
      pedido != null ? PedidoCreateModel.edit(pedido) : PedidoCreateModel(pai),
    );
    if (!form.isEdit && form.checklist == null) {
      form.checklist = BackendClient.checklists.data.firstWhereOrNull(
        (e) => e.isPadrao,
      );
    }
    if (pai != null) {
      _preencherValoresPedidoPai(pai);
    }
  }

  void _preencherValoresPedidoPai(PedidoModel pai) {
    form.localizador.text = '${pai.localizador} - Parcial';
    form.planilhamento.text = pai.planilhamento;
    form.tipo = pai.tipo;
    form.descricao.text = pai.descricao;
    form.cliente = pai.cliente;
    form.obra = pai.obra;
    // Parcial inicia sempre na etapa definida em criacaoPedido da automação,
    // assim como um pedido normal — não herda a etapa atual do Mestre.
    form.step = FirestoreClient.automatizacao.data.criacaoPedido.step ??
        BackendClient.steps.data.firstWhereOrNull((e) => e.isDefault) ??
        BackendClient.steps.getById(pai.step.id);
    if (pai.checklistId != null) {
      form.checklist = BackendClient.checklists.getById(pai.checklistId!);
    }
    form.deliveryAt = pai.deliveryAt;
    form.pedidoFinanceiro.text = pai.pedidoFinanceiro;
    form.instrucoesFinanceiras.text = pai.instrucoesFinanceiras;
    form.instrucoesEntrega.text = pai.instrucoesEntrega;

    // Ordena produtos pela bitola (valor numérico da descrição)
    final produtosOrdenados = List<PedidoBitolaModel>.from(pai.produtos)
      ..sort((a, b) {
        final prodA = BackendClient.bitolas.getById(a.produto.id);
        final prodB = BackendClient.bitolas.getById(b.produto.id);
        return prodA.number.compareTo(prodB.number);
      });

    for (final produto in produtosOrdenados) {
      final produtoBase = BackendClient.bitolas.getById(produto.produto.id);
      // pega a quantidade de Kg disponível de acordo com o produto (com base na original)
      final double qtdeTotal = produto.qtdeOriginal;
      final double qtdeDirecionada = pai.getQtdeDirecionada(produto);
      final double qtdeDisponivel = qtdeTotal - qtdeDirecionada;
      final create = PedidoBitolaCreateModel(
        isEnabled: qtdeDisponivel > 0,
        qtdeDisponivel: qtdeDisponivel,
        isSelected: false, // Inicia desmarcado — só seleciona quando preenche quantidade
      );
      create.produtoModel = produtoBase;
      create.produtoEC.text = produtoBase.descricaoReplaced;
      create.qtde.text = '0'; // Inicia zerado para o usuário preencher
      form.produtos.add(create);
    }
  }

  List<PedidoModel> getPedidosFiltered(
    String search,
    List<PedidoModel> pedidos,
  ) {
    pedidos = utils.steps.isEmpty
        ? pedidos
        : pedidos.where((e) => e.step.id == utils.steps.last.id).toList();
    if (search.length < 3) return pedidos;
    List<PedidoModel> filtered = [];
    for (final pedido in pedidos) {
      if (pedido.filtro.toCompare.contains(search.toCompare)) {
        filtered.add(pedido);
      }
    }
    return filtered;
  }

  List<PedidoModel> getPedidosArchivedsFiltered(
    String search,
    List<PedidoModel> pedidos,
  ) {
    pedidos = utilsArquiveds.steps.isEmpty
        ? pedidos
        : pedidos
            .where(
              (e) => utilsArquiveds.steps.map((e) => e.id).contains(e.step.id),
            )
            .toList();
    if (search.length < 3) return pedidos;
    List<PedidoModel> filtered = [];
    for (final pedido in pedidos) {
      if (pedido.filtro.toCompare.contains(search.toCompare)) {
        filtered.add(pedido);
      }
    }
    return filtered;
  }

  Future<void> onConfirm(value, PedidoModel? pedido, bool isFromOrder) async {
    try {
      onValid();
      if (form.produto.produtoModel != null &&
          form.produto.qtde.text.isNotEmpty) {
        if (!await showConfirmDialog(
          'Produto não confirmado',
          'Você adicionou a quantidade mas não confirmou o produto. Deseja continuar?',
        )) {
          return;
        }
      }
      if (form.isEdit) {
        final edit = form.toPedidoModel(pedido);
        // Validação: não permite gravar sem membro
        if (edit.users.isEmpty) {
          throw Exception('O pedido precisa ter pelo menos um membro responsável');
        }
        // Se NÃO é Mestre, qtdeOriginal deve acompanhar a qtde editada
        if (edit.pedidosFilhos.isEmpty) {
          for (int i = 0; i < edit.produtos.length; i++) {
            edit.produtos[i] = edit.produtos[i].copyWith(
              qtdeOriginal: edit.produtos[i].qtde,
            );
          }
        }
        verificarTags(edit);

        // ── Caso 1: troca de obra no pedido mestre ──────────────────────
        if (edit.isMestre && pedido != null) {
          final obraAnteriorId = pedido.obra.id;
          final obraNovaId = edit.obra.id;
          if (obraAnteriorId != obraNovaId && edit.pedidosFilhos.isNotEmpty) {
            final propagar = await _perguntarPropagacaoObra(
              value, // context
              edit.pedidosFilhos.length,
            );
            if (propagar) {
              await _propagarObraParaParciais(edit);
            }
          }
        }

        final update = await BackendClient.pedidos.update(edit);
        if (update != null) {
          pedidoStream.add(update);
          pedidoStream.update();
        }
      } else {
        PedidoModel pedidoModel = form.toPedidoModel(pedido);
        // Validação: não permite gravar sem membro
        if (pedidoModel.users.isEmpty) {
          throw Exception('O pedido precisa ter pelo menos um membro responsável');
        }

        // Validar saldo disponível se for pedido parcial
        if (form.pai != null) {
          final pai = BackendClient.pedidos.getById(form.pai!);
          for (final produtoFilho in pedidoModel.produtos) {
            final produtoPai = pai.produtos.firstWhereOrNull(
              (e) => e.produto.id == produtoFilho.produto.id,
            );
            if (produtoPai != null && (produtoFilho.qtde.precision > produtoPai.qtde.precision)) {
              NotificationService.showNegative(
                'Saldo Insuficiente',
                'O produto ${produtoPai.produto.nome} possui apenas ${produtoPai.qtde}Kg disponíveis.',
              );
              return;
            }
          }
        }

        final defaultCDTags =
            FirestoreClient.tags.data.where((e) => e.isDefaultCD).toList();
        final defaultCDATags =
            FirestoreClient.tags.data.where((e) => e.isDefaultCDA).toList();

        if (pedidoModel.tipo == PedidoTipo.cd && defaultCDTags.isNotEmpty) {
          pedidoModel.tags.addAll(defaultCDTags);
        } else if (pedidoModel.tipo == PedidoTipo.cda &&
            defaultCDATags.isNotEmpty) {
          pedidoModel.tags.addAll(defaultCDATags);
        }

        // Definir posição na lista conforme configuração de automação
        final pedidosDaEtapa = BackendClient.pedidos.pepidosUnarchiveds
            .where((e) => e.step.id == pedidoModel.step.id)
            .toList();
        if (automatizacaoConfig.novoPedidoNoTopo) {
          final menorIndex = pedidosDaEtapa.isEmpty
              ? 0
              : pedidosDaEtapa.map((e) => e.index).reduce((a, b) => a < b ? a : b);
          pedidoModel.index = menorIndex - 1;
        } else {
          final maiorIndex = pedidosDaEtapa.isEmpty
              ? 0
              : pedidosDaEtapa.map((e) => e.index).reduce((a, b) => a > b ? a : b);
          pedidoModel.index = maiorIndex + 1;
        }

        await BackendClient.pedidos.add(pedidoModel);
        if (form.pai != null) {
          final pai = BackendClient.pedidos.getById(form.pai!);
          pai.pedidosFilhos.add(pedidoModel.id);

          // Ao se tornar mestre, apaga a data de entrega — 
          // a entrega passa a ser controlada pelos parciais
          pai.deliveryAt = null;
          
          // Deduct quantity physically from parent
          for (final produtoFilho in pedidoModel.produtos) {
            final produtoPaiIndex = pai.produtos.indexWhere((e) => e.produto.id == produtoFilho.produto.id);
            if (produtoPaiIndex != -1) {
              final produtoPai = pai.produtos[produtoPaiIndex];
              double newQtde = (produtoPai.qtde - produtoFilho.qtde).precision;
              if (newQtde < 0) newQtde = 0;
              pai.produtos[produtoPaiIndex] = produtoPai.copyWith(qtde: newQtde);
            }
          }

          await BackendClient.pedidos.update(pai);
        }
      }
      if (isFromOrder) {
        Navigator.pop(value, form.isEdit ? pedido : null);
      } else {
        pop(value);
      }
      NotificationService.showPositive(
        'Pedido ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );

      // Audit
      final pedidoFinal = form.isEdit ? pedido : null;
      AuditService.registrar(
        acao: form.isEdit ? 'editar_pedido' : 'criar_pedido',
        modulo: 'pedido',
        entidadeId: pedidoFinal?.id ?? form.localizador.text,
        entidadeLabel: form.localizador.text,
        detalhes: {
          'cliente': form.cliente?.nome ?? '',
          'tipo': form.tipo?.name ?? '',
          'produtos': form.produtos.length,
        },
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      NotificationService.showNegative(
        'Atenção',
        msg,
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<bool> onDelete(
    value,
    PedidoModel pedido, {
    bool isPedido = true,
  }) async {
    if (await _isDeleteUnavailable(pedido)) return false;

    // Fecha a tela ANTES das operações no banco para evitar
    // que o Realtime dispare rebuild antes do pop (flash do mestre)
    if (isPedido) {
      pop(value);
    }

    // Exibe o spinner durante as operações async
    showLoadingDialog();

    // Se é parcial, desvincular do mestre e devolver quantidade antes de deletar
    if (pedido.isParcial) {
      try {
        final mestre = FirestoreClient.pedidos.getById(pedido.pai!);
        mestre.pedidosFilhos.remove(pedido.id);

        // Devolver a quantidade do parcial de volta ao mestre
        for (final produtoFilho in pedido.produtos) {
          final idx = mestre.produtos.indexWhere(
            (e) => e.produto.id == produtoFilho.produto.id,
          );
          if (idx != -1) {
            final produtoMestre = mestre.produtos[idx];
            mestre.produtos[idx] = produtoMestre.copyWith(
              qtde: produtoMestre.qtde + produtoFilho.qtde,
            );
          }
        }

        pedido.pai = null;
        // Salva o mestre com quantidade restaurada e sem o filho na lista
        await BackendClient.pedidos.update(mestre);
        await BackendClient.pedidos.update(pedido);
      } catch (e) {
        log('Erro ao desvincular parcial do mestre: $e');
      }
    }

    await BackendClient.pedidos.delete(pedido);

    // Fecha o spinner
    if (contextGlobal.mounted) Navigator.pop(contextGlobal);

    NotificationService.showPositive(
      'Pedido Excluído',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );

    // Audit
    AuditService.registrar(
      acao: 'excluir_pedido',
      modulo: 'pedido',
      entidadeId: pedido.id,
      entidadeLabel: pedido.localizador,
      detalhes: {
        'cliente': pedido.cliente.nome,
        'produtos': pedido.produtos.length,
      },
    );

    return true;
  }

  Future<bool> _isDeleteUnavailable(
    PedidoModel pedido,
  ) async {
    // Regra 0: Usuário sem permissão de excluir pedidos
    if (!usuario.podeExcluirPedido) {
      await showInfoDialog(
        'Seu perfil não possui permissão para excluir pedidos. '
        'Solicite ao administrador a liberação.',
      );
      return true;
    }

    // Regra 1: Pedido Mestre não pode ser excluído se tiver parciais
    if (pedido.isMestre) {
      NotificationService.showNegative(
        'Exclusão bloqueada',
        'O Pedido Mestre possui ${pedido.pedidosFilhos.length} parcial(is) vinculado(s). '
        'Exclua os parciais antes de excluir o Mestre.',
      );
      return true;
    }

    // Regra 2: Pedido em produção não pode ser excluído
    return !await onDeleteProcess(
      deleteTitle: 'Deseja excluir o pedido?',
      deleteMessage: 'Todos seus dados do pedido apagados do sistema',
      infoMessage:
          'Não é possível excluir o pedido, pois ele está vinculado a uma ordem de produção.',
      conditional: [...FirestoreClient.ordens.data, ...FirestoreClient.ordens.ordensArquivadas]
          .expand((e) => e.produtos.map((e) => e.pedidoId))
          .any((e) => e == pedido.id),
    );
  }

  void onValid() {
    if (form.localizador.text.isEmpty) {
      throw Exception('Localizador não pode ser vazio');
    }
    if (form.cliente == null) {
      throw Exception('Selecione o cliente do pedido');
    }
    if (form.obra == null) {
      throw Exception('Selecione a obra do pedido');
    }
    if (form.tipo == null) {
      throw Exception('Selecione o tipo do pedido');
    }
    if (form.step == null) {
      throw Exception('Selecione a etapa inicial do pedido');
    }
    // Para pedidos do tipo 'Outros', exige pelo menos uma etiqueta
    if (form.tipo == PedidoTipo.outros && form.tags.isEmpty) {
      throw Exception(
        'Pedidos do tipo "Outros" precisam ter pelo menos uma etiqueta selecionada',
      );
    }
  }

  //PEDIDO
  AppStream<PedidoModel> pedidoStream = AppStream<PedidoModel>();
  PedidoModel get pedido => pedidoStream.value;

  void setPedido(PedidoModel? pedido) {
    if (pedido != null) {
      pedidoStream.add(pedido);
    } else {
      pedidoStream = AppStream<PedidoModel>();
    }
  }

  OrdemModel? getOrdemByProduto(PedidoBitolaModel produto, bool isArquivada) {
    return ([
      ...FirestoreClient.ordens.data,
      if (isArquivada) ...FirestoreClient.ordens.ordensArquivadas,
    ]).firstWhereOrNull((e) => e.hasProduto(produto.id));
  }

  void onChangePedidoStatus(PedidoModel pedido) async {
    final status = await showPedidoStatusBottom(pedido);
    if (status == null) return;
    if (pedido.status == status) return;

    pedido.statusess.add(PedidoStatusModel.create(status));
    await automatizacaoCtrl.onSetStepByPedidoStatus([pedido]);
    pedidoStream.update();
    await BackendClient.pedidos.update(pedido);
  }

  void onChangePedidoStep(PedidoModel pedido) async {
    final step = await showPedidoStepBottom(pedido);
    if (step == null) return;
    if (pedido.step.id == step.id) return;

    kanbanCtrl.onAccept(step, pedido, 0);
    pedidoStream.update();
  }

  void onSortPedidos(List<PedidoModel> pedidos) {
    bool isAsc = utils.sortOrder == SortOrder.asc;
    switch (utils.sortType) {
      case SortType.localizator:
        pedidos.sort(
          (a, b) => isAsc
              ? a.localizador.compareTo(b.localizador)
              : b.localizador.compareTo(a.localizador),
        );
        break;
      case SortType.alfabetic:
        pedidos.sort(
          (a, b) => isAsc
              ? a.localizador.compareTo(b.localizador)
              : b.localizador.compareTo(a.localizador),
        );
        break;
      case SortType.deliveryAt:
        pedidos.sort((a, b) {
          final aDelivery = a.deliveryAt;
          final bDelivery = b.deliveryAt;
          if (aDelivery == null && bDelivery == null) return 0;
          if (aDelivery == null) return 1;
          if (bDelivery == null) return -1;
          return isAsc
              ? aDelivery.compareTo(bDelivery)
              : bDelivery.compareTo(aDelivery);
        });
        break;
      case SortType.createdAt:
        pedidos.sort(
          (a, b) => isAsc
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt),
        );
        break;
      default:
    }
  }

  // Controla a janela de proteção após uma gravação local,
  // evitando que o polling sobrescreva o dado antes do banco confirmar
  DateTime? _ultimaGravacaoLocal;

  void updatePedidoFirestore() {
    _ultimaGravacaoLocal = DateTime.now();
    pedidoStream.update();
    BackendClient.pedidos.update(pedido);
  }

  /// Atualiza os arquivos do pedido com proteção contra race condition do Realtime.
  void onArquivosChanged(List<ArchiveModel> arquivos) {
    _ultimaGravacaoLocal = DateTime.now();
    final atualizado = pedidoStream.value.copyWith(archives: arquivos);
    pedidoStream.add(atualizado);
    BackendClient.pedidos.update(atualizado);
  }

  /// Recalcula o saldo (qtde) de cada produto do mestre com base na fórmula:
  /// qtde = qtdeOriginal - soma(qtde dos filhos para o mesmo produto)
  /// Corrige inconsistências causadas por exclusões falhas de parciais.
  Future<void> recalcularSaldo(PedidoModel mestre) async {
    final filhos = mestre.getPedidosFilhos();

    for (int i = 0; i < mestre.produtos.length; i++) {
      final produto = mestre.produtos[i];
      double totalDirecionado = 0;

      for (final filho in filhos) {
        for (final prodFilho in filho.produtos) {
          if (prodFilho.produto.id == produto.produto.id) {
            totalDirecionado += prodFilho.qtde;
          }
        }
      }

      final novoSaldo = produto.qtdeOriginal - totalDirecionado;
      mestre.produtos[i] = produto.copyWith(
        qtde: novoSaldo < 0 ? 0 : novoSaldo,
      );
    }

    _ultimaGravacaoLocal = DateTime.now();
    pedidoStream.add(mestre);
    await BackendClient.pedidos.update(mestre);
    NotificationService.showPositive(
      'Saldo Recalculado',
      'O saldo de todos os produtos foi recalculado com base nos parciais.',
    );
  }

  void onAddHistory({
    required PedidoModel pedido,
    required dynamic data,
    required PedidoHistoryAction action,
    required PedidoHistoryType type,
    bool isFromAutomatizacao = false,
  }) {
    pedido.histories.add(
      PedidoHistoryModel.create(
        data: data,
        action: action,
        type: type,
        isFromAutomatizacao: isFromAutomatizacao,
      ),
    );
    BackendClient.pedidos.update(pedido);
  }

  void setPedidoUsuarios(PedidoModel pedido, List<UsuarioModel> usuarios) {
    pedido.users.clear();
    pedido.users.addAll(usuarios);
    pedidoStream.add(pedido);
    BackendClient.pedidos.update(pedido);
  }

  Future<bool> onArchive(
    value,
    PedidoModel pedido, {
    bool isPedido = true,
  }) async {
    // Regra 1: Mestre só pode ser arquivado se saldo zero (toda qtde distribuída)
    if (pedido.isMestre) {
      final temSaldoPendente = pedido.produtos.any((p) {
        final totalFilhos = pedido.getPedidosFilhos().fold<double>(
          0,
          (acc, filho) {
            final fp = filho.produtos.where(
              (fp) => fp.produto.id == p.produto.id,
            );
            return acc + fp.fold<double>(0, (a, fp) => a + fp.qtdeOriginal);
          },
        );
        return (p.qtdeOriginal - totalFilhos) > 0.001;
      });
      if (temSaldoPendente) {
        NotificationService.showNegative(
          'Arquivamento bloqueado',
          'O Pedido Mestre ainda possui saldo não distribuído. '
          'Distribua toda a quantidade nos parciais antes de arquivar.',
        );
        return false;
      }
    }

    // Regra 2: Pedido Normal/Parcial — todos os produtos precisam estar prontos
    if (!pedido.isMestre &&
        pedido.produtos.any(
          (e) => e.status.status != PedidoBitolaStatus.pronto,
        )) {
      NotificationService.showNegative(
        'Pedido não pode ser arquivado',
        'O pedido possui ordens não concluídas',
      );
      return false;
    }

    if (!await showConfirmDialog(
      'Deseja arquivar esse pedido?',
      'O pedido ficará disponível na lista de arquivados',
    )) {
      return false;
    }
    showLoadingDialog();
    pedido.isArchived = !pedido.isArchived;
    await BackendClient.pedidos.update(pedido);
    await BackendClient.pedidos.fetch();
    // Carrega (ou recarrega) a lista de arquivados para que getById
    // continue encontrando o mestre arquivado nos parciais filhos
    await BackendClient.pedidos.startOnlyArquivadas();
    if (contextGlobal.mounted) Navigator.pop(contextGlobal);
    if (isPedido) Navigator.pop(value);
    NotificationService.showPositive(
      'Pedido Arquivado!',
      'Acesse a lista de arquivados para visualizar o pedido',
      position: NotificationPosition.bottom,
    );

    // Audit
    AuditService.registrar(
      acao: 'arquivar_pedido',
      modulo: 'pedido',
      entidadeId: pedido.id,
      entidadeLabel: pedido.localizador,
      detalhes: {
        'cliente': pedido.cliente.nome,
      },
    );

    return true;
  }

  Future<void> onUnArchivePedido(value, PedidoModel pedido, int pops) async {
    if (await showConfirmDialog(
      'Deseja desarquivar o pedido?',
      'O pedido voltará para a lista de pedidos',
    )) {
      pedido.isArchived = false;
      showLoadingDialog();
      await BackendClient.pedidos.update(pedido);
      await BackendClient.pedidos.fetch();
      if (contextGlobal.mounted) Navigator.pop(contextGlobal);
      for (var i = 0; i < pops; i++) {
        Navigator.pop(value);
      }
      NotificationService.showPositive(
        'Pedido Desarquivado!',
        'Acesse a lista de pedidos para visualizar o pedido',
      );

      // Audit
      AuditService.registrar(
        acao: 'desarquivar_pedido',
        modulo: 'pedido',
        entidadeId: pedido.id,
        entidadeLabel: pedido.localizador,
        detalhes: {
          'cliente': pedido.cliente.nome,
        },
      );
    }
  }

  List<PedidoHistoryModel> getHistoricoAcompanhamento(PedidoModel pedido) {
    List<PedidoHistoryModel> histories = pedido.histories.reversed
        .where((e) => e.type == PedidoHistoryType.step)
        .toList();

    histories = histories.where((e) {
      final data = e.data as StepModel?;
      return data?.isShipping ?? false;
    }).toList();

    return histories;
  }

  int getIndexStep(PedidoHistoryModel history) {
    final stepHistory = history.data as StepModel;
    final step = BackendClient.steps.getById(stepHistory.id);
    return step.index;
  }

  Future<void> onGeneratePDF(PedidoModel pedido, {RelatorioPedidoTipo? type}) async {
    showLoadingDialog();
    try {
      final RelatorioPedidoViewModel relatorio = RelatorioPedidoViewModel();
      relatorio.cliente = BackendClient.clientes.getById(pedido.cliente.id);
      relatorio.produtos = pedido.produtos
          .map((e) => e.copyWith())
          .map((e) => e.produto)
          .toList();
      relatorio.status = pedido.produtos
          .map((e) => e.copyWith())
          .map((e) => e.status.status)
          .toSet()
          .toList();

      relatorio.tipo = type ?? (pedido.isMestre
          ? RelatorioPedidoTipo.mestre
          : RelatorioPedidoTipo.pedidos);

      final pedidosRelatorio =
          pedido.isMestre ? [pedido, ...pedido.getPedidosFilhos()] : [pedido];

      final model = RelatorioPedidoModel(
        relatorio.cliente,
        relatorio.status,
        pedidosRelatorio,
        relatorio.tipo,
        relatorio.produtos,
      );
      relatorio.relatorio = model;

      relatorioCtrl.pedidoViewModelStream.add(relatorio);

      await relatorioCtrl.onExportRelatorioPedidoPDF(
        relatorio,
        name: pedido.localizador,
        quantidade: RelatorioPedidoQuantidade.unico,
      );
    } catch (e, stackTrace) {
      log(stackTrace.toString());
      log(e.toString());
      NotificationService.showNegative('Erro ao gerar relatório', e.toString());
    }
    if (contextGlobal.mounted) Navigator.pop(contextGlobal);
  }

  void onFixComment(PedidoModel pedido, int index) {
    for (var i = 0; i < pedido.comments.length; i++) {
      if (i == index) {
        pedido.comments[i].isFixed = !pedido.comments[i].isFixed;
      }
    }
    BackendClient.pedidos.update(pedido);
    pedidoStream.update();
  }

  void onAddPedidoVinculado(PedidoModel pedido, PedidoModel pedidoVinculado) {
    pedido.pedidosVinculados.add(pedidoVinculado.id);
    pedidoVinculado.pedidosVinculados.add(pedido.id);
    BackendClient.pedidos.update(pedido);
    BackendClient.pedidos.update(pedidoVinculado);
    pedidoStream.update();
  }

  Future<void> onRemovePedidoVinculado(
    PedidoModel pedido,
    PedidoModel pedidoVinculado,
  ) async {
    if (!await showConfirmDialog(
      'Deseja remover o pedido da lista de vinculados?',
      'O pedido será removido',
    )) {
      return;
    }
    pedido.pedidosVinculados.remove(pedidoVinculado.id);
    pedidoVinculado.pedidosVinculados.remove(pedido.id);
    BackendClient.pedidos.update(pedido);
    BackendClient.pedidos.update(pedidoVinculado);
    pedidoStream.update();
  }

  Future<void> onRemovePedidoFilho(
    PedidoModel pedido,
    PedidoModel pedidoFilho,
  ) async {
    if (!await showConfirmDialog(
      'Deseja remover o pedido da lista de vinculados?',
      'O pedido será removido',
    )) {
      return;
    }
    pedido.pedidosFilhos.remove(pedidoFilho.id);
    pedidoFilho.pai = null;
    BackendClient.pedidos.update(pedido);
    BackendClient.pedidos.update(pedidoFilho);
    pedidoStream.update();
  }

  void onSortPedidosArchiveds(List<PedidoModel> pedidos) {
    bool isAsc = utilsArquiveds.sortOrder == SortOrder.asc;
    switch (utilsArquiveds.sortType) {
      case SortType.localizator:
        pedidos.sort(
          (a, b) => isAsc
              ? a.localizador.compareTo(b.localizador)
              : b.localizador.compareTo(a.localizador),
        );
        break;
      case SortType.alfabetic:
        pedidos.sort(
          (a, b) => isAsc
              ? a.localizador.compareTo(b.localizador)
              : b.localizador.compareTo(a.localizador),
        );
        break;
      case SortType.deliveryAt:
        pedidos.sort((a, b) {
          final aDelivery = a.deliveryAt;
          final bDelivery = b.deliveryAt;
          if (aDelivery == null && bDelivery == null) return 0;
          if (aDelivery == null) return 1;
          if (bDelivery == null) return -1;
          return isAsc
              ? aDelivery.compareTo(bDelivery)
              : bDelivery.compareTo(aDelivery);
        });
        break;
      case SortType.createdAt:
        pedidos.sort(
          (a, b) => isAsc
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt),
        );
        break;
      default:
    }
  }

  Future<void> onUpdateObraEndereco(
    PedidoModel pedido,
    EnderecoModel endereco,
  ) async {
    showLoadingDialog();
    try {
      // Atualização cirúrgica apenas do JSONB endereco no Supabase
      await ClienteSupabaseCollection().updateObraEndereco(pedido.obra.id, endereco);
      // Atualiza em memória
      pedido.obra.endereco = endereco;
      pedidoStream.update();
      NotificationService.showPositive(
        'Endereço atualizado',
        'Endereço da obra salvo com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao atualizar endereço',
        e.toString(),
      );
    }
    if (contextGlobal.mounted) Navigator.pop(contextGlobal);
  }

  /// Atualiza descrição e/ou endereço da obra de forma cirúrgica.
  Future<void> onUpdateObraCompleto(
    PedidoModel pedido, {
    required String descricao,
    EnderecoModel? endereco,
  }) async {
    final supabase = ClienteSupabaseCollection();

    // Salva descrição se mudou
    if (descricao != pedido.obra.descricao) {
      await supabase.updateObraDescricao(pedido.obra.id, descricao);
      pedido.obra.descricao = descricao;
    }

    // Salva endereço se foi alterado
    if (endereco != null) {
      await supabase.updateObraEndereco(pedido.obra.id, endereco);
      pedido.obra.endereco = endereco;
    }

    pedidoStream.update();
    NotificationService.showPositive(
      'Obra atualizada',
      'Descrição e endereço salvos com sucesso',
      position: NotificationPosition.bottom,
    );
  }


  void verificarTags(PedidoModel edit) {
    // Lógica antiga (que forçava etiqueta CDA) foi removida a pedido do usuário
  }

  // ── Propagação de obra para parciais ─────────────────────────────────────

  /// Pergunta ao usuário se deseja propagar a troca de obra aos parciais.
  Future<bool> _perguntarPropagacaoObra(BuildContext context, int qtd) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            icon: Icon(Icons.info_outline,
                size: 40, color: Colors.orange[700]),
            title: const Text('Pedido Mestre'),
            content: Text(
              'A obra foi alterada. Este pedido possui $qtd '
              'parcial${qtd > 1 ? 'is' : ''}. '
              'Deseja aplicar a mesma obra a eles também?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Não, só o mestre'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Sim, aplicar aos $qtd'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Propaga a obra do mestre para todos os pedidos parciais.
  Future<void> _propagarObraParaParciais(PedidoModel mestre) async {
    final filhos = FirestoreClient.pedidos.data
        .where((p) => mestre.pedidosFilhos.contains(p.id))
        .toList();

    for (final filho in filhos) {
      filho.obra = mestre.obra;
      await BackendClient.pedidos.update(filho);
    }
  }
}
