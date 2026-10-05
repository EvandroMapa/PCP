import 'dart:async';
import 'dart:developer';

import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/automatizacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/cliente/cliente_supabase_collection.dart';
import 'package:aco_plus/app/core/components/archive/archive_model.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/dialogs/loading_dialog.dart';
import 'package:aco_plus/app/core/enums/sort_type.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
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
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
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

  /// [recarregar] = false na abertura do app: os pedidos chegam pela carga
  /// inicial do AppSupabaseClient (buscar aqui montava pedidos sem elementos).
  void onInit({bool recarregar = true}) {
    try {
      utilsStream.add(PedidoUtils());
      if (recarregar) {
        BackendClient.pedidos.fetch();
      }
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

    // Se for pedido mestre, garante que os filhos arquivados (sem ordem ativa)
    // estejam no cache para exibição correta na aba Bitolas.
    if (pedido.pedidosFilhos.isNotEmpty) {
      BackendClient.pedidos.fetchFilhosArquivadosDoPedido(pedido.pedidosFilhos);
    }

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
          // Re-busca os filhos arquivados após o fetch do mestre atualizado,
          // pois a lista de pedidosFilhos pode ter sido atualizada.
          if (updated.pedidosFilhos.isNotEmpty) {
            await BackendClient.pedidos
                .fetchFilhosArquivadosDoPedido(updated.pedidosFilhos);
          }
          pedidoStream.add(updated);
          SchedulerBinding.instance.scheduleFrame();
        }
      }
    });

    // Polling de 3s REMOVIDO — o Realtime já cuida da sincronização.
    // O polling antigo causava queries pesadas a cada 3s conflitando
    // com o Realtime e gerando congelamentos de 5-20s.
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

      // Disponível = qtdeOriginal do mestre − Σ(qtde dos filhos para essa bitola)
      // Mesma fórmula usada na tabela de saldo da aba Bitolas, garantindo consistência.
      // Usa BackendClient (Supabase) — getPedidosFilhos() usa FirestoreClient (legado)
      // e pode retornar lista incompleta quando os filhos não estão no cache do Firestore.
      final filhos = pai.pedidosFilhos
          .map((id) => BackendClient.pedidos.getById(id))
          .where((f) => !f.localizador.startsWith('NOTFOUND'))
          .toList();
      final totalDirecionado = filhos.fold<double>(0, (acc, filho) {
        final fp =
            filho.produtos.where((p) => p.produto.id == produto.produto.id);
        return acc + fp.fold<double>(0, (a, p) => a + p.qtde);
      });
      final double qtdeDisponivel =
          (produto.qtdeOriginal - totalDirecionado).clamp(0, double.infinity);

      final create = PedidoBitolaCreateModel(
        isEnabled: qtdeDisponivel > 0,
        qtdeDisponivel: qtdeDisponivel,
        isSelected:
            false, // Inicia desmarcado — só seleciona quando preenche quantidade
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
    // Ordenar por arquivados mais recentes (último archive.createdAt)
    pedidos.sort((a, b) {
      final aDate =
          a.archives.isNotEmpty ? a.archives.last.createdAt : a.createdAt;
      final bDate =
          b.archives.isNotEmpty ? b.archives.last.createdAt : b.createdAt;
      return bDate.compareTo(aDate); // desc: mais recente primeiro
    });
    if (search.length < 2) return pedidos;
    return pedidos
        .where((e) => e.localizador.toCompare.contains(search.toCompare))
        .toList();
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
          throw Exception(
              'O pedido precisa ter pelo menos um membro responsável');
        }
        // Se NÃO é Mestre e nunca teve parciais, qtdeOriginal deve acompanhar a qtde editada (inclusive para parciais)
        if (!edit.isMestre && edit.pedidosFilhos.isEmpty) {
          for (int i = 0; i < edit.produtos.length; i++) {
            edit.produtos[i] = edit.produtos[i].copyWith(
              qtdeOriginal: edit.produtos[i].qtde,
            );
          }
        }
        verificarTags(edit);

        // ── Validação se for edição de pedido parcial ──────────────────────
        if (edit.isParcial && edit.pai != null && edit.pai!.isNotEmpty) {
          final pai = BackendClient.pedidos.getById(edit.pai!);
          if (!pai.localizador.startsWith('NOTFOUND')) {
            final outrosFilhos = pai.pedidosFilhos
                .where((id) => id != edit.id)
                .map((id) => BackendClient.pedidos.getById(id))
                .where((f) => !f.localizador.startsWith('NOTFOUND'))
                .toList();

            for (final produtoFilho in edit.produtos) {
              final produtoPai = pai.produtos.firstWhereOrNull(
                (e) => e.produto.id == produtoFilho.produto.id,
              );
              if (produtoPai == null) {
                NotificationService.showNegative(
                  'Bitola não permitida',
                  'A bitola ${produtoFilho.produto.descricao} não pertence ao pedido mestre.',
                  position: NotificationPosition.bottom,
                );
                return;
              }
              final double consumidoOutros =
                  outrosFilhos.fold<double>(0.0, (acc, filho) {
                final fp = filho.produtos
                    .where((p) => p.produto.id == produtoFilho.produto.id);
                return acc + fp.fold<double>(0.0, (a, p) => a + p.qtde);
              });
              final double saldoDisponivel =
                  (produtoPai.qtdeOriginal - consumidoOutros)
                      .clamp(0.0, double.infinity)
                      .toDouble()
                      .precision;

              if (produtoFilho.qtde.toDouble().precision > saldoDisponivel) {
                NotificationService.showNegative(
                  'Saldo Insuficiente',
                  'O produto ${produtoPai.produto.nome} possui apenas ${saldoDisponivel.toKg()} disponíveis no mestre.',
                  position: NotificationPosition.bottom,
                );
                return;
              }
            }
          }
        }

        // ── Se for edição do próprio mestre, valida se houve alteração indevida de bitola consumida ──
        if ((edit.isMestre || edit.pedidosFilhos.isNotEmpty) && pedido != null) {
          for (final prodEdit in edit.produtos) {
            final prodAntigo = pedido.produtos
                .firstWhereOrNull((p) => p.produto.id == prodEdit.produto.id);
            if (prodAntigo != null) {
              final totalConsumido = edit.pedidosFilhos
                  .map((id) => BackendClient.pedidos.getById(id))
                  .where((f) => !f.localizador.startsWith('NOTFOUND'))
                  .fold<double>(0, (acc, f) {
                final fp = f.produtos
                    .where((p) => p.produto.id == prodEdit.produto.id);
                return acc + fp.fold<double>(0, (a, p) => a + p.qtde);
              });
              if (totalConsumido > 0 &&
                  (prodEdit.qtdeOriginal - prodAntigo.qtdeOriginal).abs() > 0.001) {
                NotificationService.showNegative(
                  'Edição bloqueada',
                  'A bitola ${prodEdit.produto.descricao} já possui parciais direcionados. '
                  'Sua quantidade original não pode ser alterada.',
                  position: NotificationPosition.bottom,
                );
                return;
              }
            }
          }
          recalcularSaldosMestreInterno(edit);
        }

        // ── Caso 1: troca de obra no pedido mestre ──────────────────────
        if (edit.isMestre && pedido != null) {
          final obraAnteriorId = pedido.obra.id;
          final obraNovaId = edit.obra.id;
          final filhosReais = edit.getPedidosFilhos();
          if (obraAnteriorId != obraNovaId && filhosReais.isNotEmpty) {
            final propagar = await _perguntarPropagacaoObra(
              value, // context
              filhosReais.length,
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

          // ── Se for pedido parcial, recalcula e atualiza o pedido mestre ──
          if (edit.isParcial && edit.pai != null && edit.pai!.isNotEmpty) {
            final pai = BackendClient.pedidos.getById(edit.pai!);
            if (!pai.localizador.startsWith('NOTFOUND')) {
              if (!pai.pedidosFilhos.contains(edit.id)) {
                pai.pedidosFilhos.add(edit.id);
              }
              recalcularSaldosMestreInterno(pai,
                  novosFilhosAdicionais: [update]);
              await BackendClient.pedidos.update(pai);
            }
          }
        }
      } else {
        PedidoModel pedidoModel = form.toPedidoModel(pedido);
        // Validação: não permite gravar sem membro
        if (pedidoModel.users.isEmpty) {
          throw Exception(
              'O pedido precisa ter pelo menos um membro responsável');
        }

        // Validar saldo disponível se for pedido parcial
        if (form.pai != null) {
          final pai = BackendClient.pedidos.getById(form.pai!);
          if (!pai.localizador.startsWith('NOTFOUND')) {
            final filhos = pai.pedidosFilhos
                .map((id) => BackendClient.pedidos.getById(id))
                .where((f) => !f.localizador.startsWith('NOTFOUND'))
                .toList();

            for (final produtoFilho in pedidoModel.produtos) {
              final produtoPai = pai.produtos.firstWhereOrNull(
                (e) => e.produto.id == produtoFilho.produto.id,
              );
              if (produtoPai == null) {
                NotificationService.showNegative(
                  'Bitola não permitida',
                  'A bitola ${produtoFilho.produto.descricao} não pertence ao pedido mestre.',
                  position: NotificationPosition.bottom,
                );
                return;
              }
              final double consumidoFilhos =
                  filhos.fold<double>(0.0, (acc, filho) {
                final fp = filho.produtos
                    .where((p) => p.produto.id == produtoFilho.produto.id);
                return acc + fp.fold<double>(0.0, (a, p) => a + p.qtde);
              });
              final double saldoDisponivel =
                  (produtoPai.qtdeOriginal - consumidoFilhos)
                      .clamp(0.0, double.infinity)
                      .toDouble()
                      .precision;

              if (produtoFilho.qtde.toDouble().precision > saldoDisponivel) {
                NotificationService.showNegative(
                  'Saldo Insuficiente',
                  'O produto ${produtoPai.produto.nome} possui apenas ${saldoDisponivel.toKg()} disponíveis no mestre.',
                  position: NotificationPosition.bottom,
                );
                return;
              }
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
              : pedidosDaEtapa
                  .map((e) => e.index)
                  .reduce((a, b) => a < b ? a : b);
          pedidoModel.index = menorIndex - 1;
        } else {
          final maiorIndex = pedidosDaEtapa.isEmpty
              ? 0
              : pedidosDaEtapa
                  .map((e) => e.index)
                  .reduce((a, b) => a > b ? a : b);
          pedidoModel.index = maiorIndex + 1;
        }

        await BackendClient.pedidos.add(pedidoModel);
        if (form.pai != null) {
          final pai = BackendClient.pedidos.getById(form.pai!);
          if (!pai.pedidosFilhos.contains(pedidoModel.id)) {
            pai.pedidosFilhos.add(pedidoModel.id);
          }

          // Ao se tornar mestre, apaga a data de entrega —
          // a entrega passa a ser controlada pelos parciais
          pai.deliveryAt = null;

          // Recálculo determinístico de saldo de todos os produtos do mestre
          recalcularSaldosMestreInterno(
            pai,
            novosFilhosAdicionais: [pedidoModel],
          );

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

    // Se é parcial, desvincular do mestre e recalcular quantidade antes de deletar
    if (pedido.isParcial && pedido.pai != null && pedido.pai!.isNotEmpty) {
      try {
        final mestre = BackendClient.pedidos.getById(pedido.pai!);
        mestre.pedidosFilhos.remove(pedido.id);

        // Recálculo determinístico de saldo de todos os produtos do mestre (já sem o filho)
        recalcularSaldosMestreInterno(mestre);

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
    // Usa getPedidosFilhos() para ignorar IDs fantasma de parciais já excluídos
    final filhosReais = pedido.getPedidosFilhos();
    if (filhosReais.isNotEmpty) {
      NotificationService.showNegative(
        'Exclusão bloqueada',
        'O Pedido Mestre possui ${filhosReais.length} parcial(is) vinculado(s). '
            'Exclua os parciais antes de excluir o Mestre.',
      );
      return true;
    }

    // Limpar IDs fantasma (parciais já excluídos mas cujo ID ficou no array)
    if (pedido.pedidosFilhos.isNotEmpty && filhosReais.isEmpty) {
      pedido.pedidosFilhos.clear();
      await BackendClient.pedidos.update(pedido);
    }

    // Regra 2: Pedido em produção não pode ser excluído
    return !await onDeleteProcess(
      deleteTitle: 'Deseja excluir o pedido?',
      deleteMessage: 'Todos seus dados do pedido apagados do sistema',
      infoMessage:
          'Não é possível excluir o pedido, pois ele está vinculado a uma ordem de produção.',
      conditional: [
        ...FirestoreClient.ordens.data,
        ...FirestoreClient.ordens.ordensArquivadas
      ]
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

  /// Recalcula o saldo (qtde) de cada produto do mestre de forma determinística:
  /// qtde = max(0, qtdeOriginal - soma(qtde dos filhos ativos para a bitola))
  /// Limpa também IDs fantasmas de parciais que não existem mais.
  void recalcularSaldosMestreInterno(
    PedidoModel mestre, {
    List<PedidoModel>? novosFilhosAdicionais,
  }) {
    final todosFilhos = <PedidoModel>[];
    final idsValidos = <String>{};

    for (final id in mestre.pedidosFilhos) {
      final filhoSubstituido =
          novosFilhosAdicionais?.firstWhereOrNull((nf) => nf.id == id);
      if (filhoSubstituido != null) {
        todosFilhos.add(filhoSubstituido);
        idsValidos.add(filhoSubstituido.id);
      } else {
        final f = BackendClient.pedidos.getById(id);
        if (!f.localizador.startsWith('NOTFOUND')) {
          todosFilhos.add(f);
          idsValidos.add(f.id);
        }
      }
    }
    if (novosFilhosAdicionais != null) {
      for (final nf in novosFilhosAdicionais) {
        if (!idsValidos.contains(nf.id)) {
          todosFilhos.add(nf);
          idsValidos.add(nf.id);
        }
      }
    }
    mestre.pedidosFilhos.retainWhere((id) => idsValidos.contains(id));

    for (int i = 0; i < mestre.produtos.length; i++) {
      final produto = mestre.produtos[i];
      double totalDirecionado = 0.0;

      for (final filho in todosFilhos) {
        for (final prodFilho in filho.produtos) {
          if (prodFilho.produto.id == produto.produto.id) {
            totalDirecionado += prodFilho.qtde;
          }
        }
      }

      final double novoSaldo = (produto.qtdeOriginal - totalDirecionado)
          .clamp(0.0, double.infinity)
          .toDouble()
          .precision;
      mestre.produtos[i] = produto.copyWith(qtde: novoSaldo);
    }
  }

  /// Recalcula o saldo (qtde) de cada produto do mestre com base na fórmula:
  /// qtde = qtdeOriginal - soma(qtde dos filhos para o mesmo produto)
  /// Corrige inconsistências causadas por exclusões falhas de parciais.
  Future<void> recalcularSaldo(PedidoModel mestre) async {
    await BackendClient.pedidos
        .fetchFilhosArquivadosDoPedido(mestre.pedidosFilhos);
    recalcularSaldosMestreInterno(mestre);

    _ultimaGravacaoLocal = DateTime.now();
    pedidoStream.add(mestre);
    await BackendClient.pedidos.update(mestre);
    NotificationService.showPositive(
      'Saldo Recalculado',
      'O saldo de todos os produtos foi recalculado com base nos parciais.',
      position: NotificationPosition.bottom,
    );
  }

  /// Verifica se há divergências de saldo entre o mestre e seus parciais.
  /// Se não houver divergência, apenas avisa o usuário.
  /// Se houver, exibe diálogo com o comparativo de cada bitola e pede confirmação antes de atualizar.
  Future<void> verificarERecalcularSaldo(
    BuildContext context,
    PedidoModel mestre,
  ) async {
    // Garante que todos os filhos (inclusive os arquivados) estejam em cache antes de calcular
    await BackendClient.pedidos
        .fetchFilhosArquivadosDoPedido(mestre.pedidosFilhos);

    final todosFilhos = <PedidoModel>[];
    final idsValidos = <String>{};

    for (final id in mestre.pedidosFilhos) {
      final f = BackendClient.pedidos.getById(id);
      if (!f.localizador.startsWith('NOTFOUND')) {
        todosFilhos.add(f);
        idsValidos.add(f.id);
      }
    }

    final int qtdFantasmas = mestre.pedidosFilhos.length - idsValidos.length;
    final divergencias = <DivergenciaSaldoBitola>[];

    for (final produto in mestre.produtos) {
      double totalDirecionado = 0.0;
      for (final filho in todosFilhos) {
        for (final prodFilho in filho.produtos) {
          if (prodFilho.produto.id == produto.produto.id) {
            totalDirecionado += prodFilho.qtde;
          }
        }
      }

      final double saldoCalculado = (produto.qtdeOriginal - totalDirecionado)
          .clamp(0.0, double.infinity)
          .toDouble()
          .precision;
      final double saldoAtual = produto.qtde.toDouble().precision;

      // Inconsistência 1: Saldo gravado no mestre difere do saldo calculado
      final bool saldoDivergente = (saldoCalculado - saldoAtual).abs() > 0.001;

      // Inconsistência 2: Estouro — os parciais consumiram mais do que a quantidade original
      final bool isEstouro = totalDirecionado > (produto.qtdeOriginal + 0.001);

      if (saldoDivergente || isEstouro) {
        divergencias.add(
          DivergenciaSaldoBitola(
            bitolaDescricao: produto.produto.descricao,
            qtdeOriginal: produto.qtdeOriginal.toDouble().precision,
            totalParciais: totalDirecionado.toDouble().precision,
            saldoAtual: saldoAtual,
            saldoCalculado: saldoCalculado,
            isEstouro: isEstouro,
          ),
        );
      }
    }

    if (divergencias.isEmpty && qtdFantasmas == 0) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
            title: const Text('Saldos Consistentes', textAlign: TextAlign.center),
            content: Text(
              'Todos os produtos do pedido mestre "${mestre.localizador}" '
              'estão com os saldos perfeitamente consistentes com os pedidos parciais.\n\n'
              'Não há divergências a corrigir.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final confirmar = await _mostrarDialogoDivergencias(
      context,
      mestre,
      divergencias,
      qtdFantasmas,
    );

    if (confirmar != true) return;

    showLoadingDialog();
    try {
      await recalcularSaldo(mestre);
    } finally {
      if (contextGlobal.mounted) Navigator.pop(contextGlobal);
    }
  }

  Future<bool?> _mostrarDialogoDivergencias(
    BuildContext context,
    PedidoModel mestre,
    List<DivergenciaSaldoBitola> divergencias,
    int qtdFantasmas,
  ) {
    final bool temEstouro = divergencias.any((d) => d.isEstouro);

    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
        title: const Text(
          'Divergência de Saldo',
          textAlign: TextAlign.center,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foram identificadas inconsistências no pedido mestre ${mestre.localizador}:',
                style: AppCss.mediumRegular.setColor(const Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              if (divergencias.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEDF2F7),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text('Bitola', style: AppCss.minimumBold),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Original',
                                  textAlign: TextAlign.right,
                                  style: AppCss.minimumBold),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Parciais',
                                  textAlign: TextAlign.right,
                                  style: AppCss.minimumBold),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Saldo',
                                  textAlign: TextAlign.right,
                                  style: AppCss.minimumBold),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text('Diferença',
                                  textAlign: TextAlign.right,
                                  style: AppCss.minimumBold),
                            ),
                          ],
                        ),
                      ),
                      ...divergencias.map((d) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFF1F5F9)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  d.bitolaDescricao,
                                  style: AppCss.minimumRegular
                                      .setColor(const Color(0xFF1E293B)),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  d.qtdeOriginal.toKg(),
                                  textAlign: TextAlign.right,
                                  style: AppCss.minimumRegular
                                      .setColor(Colors.grey[700]!),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  d.totalParciais.toKg(),
                                  textAlign: TextAlign.right,
                                  style: AppCss.minimumRegular
                                      .setColor(Colors.grey[800]!),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  d.saldoAtual.toKg(),
                                  textAlign: TextAlign.right,
                                  style: AppCss.minimumBold
                                      .setColor(const Color(0xFF15803D)),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  d.isEstouro
                                      ? 'Estouro -${d.excesso.toKg()}'
                                      : '${d.diferenca > 0 ? '+' : ''}${d.diferenca.toKg()}',
                                  textAlign: TextAlign.right,
                                  style: AppCss.minimumBold.setColor(
                                    (d.isEstouro || d.diferenca < 0)
                                        ? AppColors.error
                                        : Colors.blue[700]!,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              if (temEstouro) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 18, color: Colors.red[800]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Atenção: A quantidade direcionada aos parciais excedeu a quantidade original (estouro). O saldo disponível do mestre será mantido em 0 kg.',
                          style: AppCss.minimumRegular
                              .setColor(Colors.red[900]!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (qtdFantasmas > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: Colors.orange[800]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$qtdFantasmas parcial(is) excluído(s) ainda constavam vinculados e serão limpos.',
                          style: AppCss.minimumRegular
                              .setColor(Colors.orange[900]!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Deseja atualizar e sincronizar os saldos do pedido mestre?',
                style: AppCss.mediumBold.setSize(13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Atualizar Saldo'),
          ),
        ],
      ),
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
            return acc + fp.fold<double>(0, (a, fp) => a + fp.qtde);
          },
        );
        return (p.qtdeOriginal - totalFilhos) > 0.001;
      });
      if (temSaldoPendente) {
        NotificationService.showNegative(
          'Arquivamento bloqueado',
          'O Pedido Mestre ainda possui saldo não distribuído. '
              'Distribua toda a quantidade nos parciais antes de arquivar.',
          position: NotificationPosition.bottom,
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
        position: NotificationPosition.bottom,
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

    // Sugestão: se arquivou um parcial e agora todos os filhos do mestre estão arquivados
    if (pedido.isParcial && pedido.pai != null && pedido.pai!.isNotEmpty) {
      // IMPORTANTE: usar BackendClient (Supabase), não FirestoreClient (legado).
      // Também busca após o fetch() para pegar o estado atualizado dos filhos.
      final mestre = BackendClient.pedidos.getById(pedido.pai!);
      if (!mestre.localizador.startsWith('NOTFOUND') &&
          !mestre.isArchived &&
          mestre.todosFilhosArquivados &&
          contextGlobal.mounted) {
        final arquivarMestre = await showDialog<bool>(
          context: contextGlobal,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.archive_outlined,
                size: 40, color: Colors.green[700]),
            title: const Text('Todos os parciais arquivados!'),
            content: Text(
              'Todos os pedidos parciais de "${mestre.localizador}" foram arquivados.\n\n'
              'Deseja arquivar o Pedido Mestre também?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Agora não'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Arquivar Mestre'),
              ),
            ],
          ),
        );
        if (arquivarMestre == true && contextGlobal.mounted) {
          await onArchive(contextGlobal, mestre, isPedido: false);
        }
      }
    }

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

      // Remove o pedido da lista de arquivados diretamente no stream.
      // Isso garante que o StreamBuilder receba o evento e atualize a UI
      // imediatamente, sem depender de re-fetch ou timing de rebuild.
      final arquivadosAtuais = BackendClient.pedidos.pedidosArchiveds
          .where((p) => p.id != pedido.id)
          .toList();
      BackendClient.pedidos.pedidosArchivedsStream.add(arquivadosAtuais);

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

  Future<void> onGeneratePDF(PedidoModel pedido,
      {RelatorioPedidoTipo? type}) async {
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

      relatorio.tipo = type ??
          (pedido.isMestre
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
    recalcularSaldosMestreInterno(pedido);
    BackendClient.pedidos.update(pedido);
    BackendClient.pedidos.update(pedidoFilho);
    pedidoStream.update();
  }

  void onSortPedidosArchiveds(List<PedidoModel> pedidos) {
    // Ordenação já feita em getPedidosArchivedsFiltered — sem ação extra.
  }

  Future<void> onUpdateObraEndereco(
    PedidoModel pedido,
    EnderecoModel endereco,
  ) async {
    showLoadingDialog();
    try {
      // Atualização cirúrgica apenas do JSONB endereco no Supabase
      await ClienteSupabaseCollection()
          .updateObraEndereco(pedido.obra.id, endereco);
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
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
    final filhos = BackendClient.pedidos.data
        .where((p) => mestre.pedidosFilhos.contains(p.id))
        .toList();

    for (final filho in filhos) {
      filho.obra = mestre.obra;
      await BackendClient.pedidos.update(filho);
    }
  }
}

class DivergenciaSaldoBitola {
  final String bitolaDescricao;
  final double qtdeOriginal;
  final double totalParciais;
  final double saldoAtual;
  final double saldoCalculado;
  final bool isEstouro;

  /// Excesso consumido acima da quantidade original quando há estouro
  double get excesso => (totalParciais - qtdeOriginal).precision;

  /// Diferença para exibir: se estouro, é o excesso negativo; se divergência de saldo, é (calculado - atual)
  double get diferenca => isEstouro
      ? -excesso
      : (saldoCalculado - saldoAtual).precision;

  DivergenciaSaldoBitola({
    required this.bitolaDescricao,
    required this.qtdeOriginal,
    required this.totalParciais,
    required this.saldoAtual,
    required this.saldoCalculado,
    this.isEstouro = false,
  });
}

