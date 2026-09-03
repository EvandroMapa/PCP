import 'dart:developer';
import 'dart:async';
import 'package:collection/collection.dart';

import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/automatizacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/enums/sort_step_type.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedidos_vinculados_move_select_dialog.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

const stepIdAguardandoProd = 'E2chjojxDVgeHa3i248t3Xl5O';

final kanbanCtrl = StepController();

class StepController {
  static final StepController _instance = StepController._();

  StepController._();

  factory StepController() => _instance;

  final AppStream<KanbanUtils> utilsStream = AppStream<KanbanUtils>();
  KanbanUtils get utils => utilsStream.value;

  /// Bloqueia rebuilds do stream durante o arrasto de cartoes
  bool isDragging = false;

  /// Bloqueia fetch do backend por um curto periodo apos o drop,
  /// evitando que dados antigos sobreescrevam o estado otimista.
  bool _pendingDrop = false;
  bool get isDropLocked => isDragging || _pendingDrop;
  StreamSubscription? _pedidosSubscription;
  Timer? _mountDebounce;
  Timer? _dropTimer;

  void startDrag() {
    _dropTimer?.cancel();
    _pendingDrop = false;
    isDragging = true;
  }

  void endDrag() {
    if (!isDragging && !_pendingDrop) return; // guard: já processado
    // Ativa _pendingDrop ANTES de desligar isDragging para não abrir janela
    _pendingDrop = true;
    isDragging = false;
    // Cancela timer anterior caso endDrag seja chamado múltiplas vezes
    _dropTimer?.cancel();
    _dropTimer = Timer(const Duration(milliseconds: 3000), () {
      _pendingDrop = false;
      // Não faz fetch: o Realtime já trouxe o estado correto.
      // Se precisar forçar sincronia, descomente:
      // BackendClient.pedidos.fetch();
    });
  }

  Future<void> onInit() async {
    try {
      _pedidosSubscription?.cancel();
      _pedidosSubscription =
          BackendClient.pedidos.dataStream.listen.listen((_) {
        if (!isDropLocked) {
          updateKanban();
          SchedulerBinding.instance.addPostFrameCallback((_) {
            SchedulerBinding.instance.ensureVisualUpdate();
          });
        }
      });

      await BackendClient.pedidos.fetch();
      final kanban = mountKanban();
      final calendar = _mountCalendar();
      utilsStream.add(KanbanUtils(kanban: kanban, calendar: calendar));



      onMount();
    } catch (e) {
      log('StepController: Erro no onInit', error: e);
    }
  }

  void onMount() {
    // Debounce: coalesce múltiplas chamadas em 200ms
    _mountDebounce?.cancel();
    _mountDebounce = Timer(const Duration(milliseconds: 200), () {
      final kanban = mountKanban();
      final calendar = _mountCalendar();
      utils.calendar = calendar;
      utils.kanban = kanban;
      utilsStream.update();
    });
  }

  Map<StepModel, List<PedidoModel>> mountKanban() {
    try {
      final pedidos = BackendClient.pedidos.pepidosUnarchiveds.toList();
      final kanban = <StepModel, List<PedidoModel>>{};
      final stepsData = BackendClient.steps.data.toList();

      if (stepsData.isEmpty) return kanban;

      for (StepModel step in stepsData) {
        final pedidosStep = pedidos.where((e) => e.step.id == step.id).toList();

        // ProteÃ§Ã£o contra index nulo ou erros de comparaÃ§Ã£o
        pedidosStep.sort((a, b) {
          try {
            return (a.index).compareTo(b.index);
          } catch (_) {
            return 0;
          }
        });

        kanban.addAll({step: pedidosStep});
      }
      return kanban;
    } catch (e) {
      log('StepController: Erro no mountKanban', error: e);
      return {};
    }
  }

  Future<void> onMountCalendar() async {
    await BackendClient.pedidos.fetch();
    utils.calendar = _mountCalendar();
    utilsStream.update();
  }

  Map<String, List<PedidoModel>> _mountCalendar() {
    final calendar = <String, List<PedidoModel>>{};

    // Filtramos apenas pedidos nÃ£o arquivados que tÃªm data de entrega
    final pedidosCalendario = BackendClient.pedidos.pepidosUnarchiveds
        .where((e) => e.deliveryAt != null)
        .toList();

    for (final pedido in pedidosCalendario) {
      // Formata a data de entrega ignorando o horÃ¡rio, apenas dia, mÃªs e ano
      final diaKey = DateFormat('dd/MM/yyyy').format(pedido.deliveryAt!);

      if (!calendar.containsKey(diaKey)) {
        calendar[diaKey] = [];
      }
      calendar[diaKey]!.add(pedido);
    }

    return calendar;
  }

  void updateKanban() {
    if (!utilsStream.hasValue) return;
    utils.kanban = mountKanban();
    utilsStream.update();
  }

  void setPedido(PedidoModel? pedido) {
    if (pedido != null) {
      if (pedido.deliveryAt != null) {
        utils.focusedDay = pedido.deliveryAt!;
      }
    }
    utils.pedido = pedido;
    utilsStream.update();
  }

  void setDay(Map<DateTime, List<PedidoModel>>? day) {
    if (day != null) {
      if (day.keys.isNotEmpty) {
        utils.focusedDay = day.keys.first;
      }
    }
    utils.day = day;
    utilsStream.update();
  }

  void setNextDay(DateTime currentDate) async {
    DateTime nextDate = currentDate.onlyDate().add(const Duration(days: 1));
    if (nextDate.weekday == DateTime.saturday) {
      nextDate = nextDate.add(const Duration(days: 2));
    }
    final pedidos = utils.calendar[nextDate.ddMMyyyy()] ?? [];
    setDay({nextDate: pedidos});
    utils.focusedDay = nextDate;
    utilsStream.update();
  }

  void setPreviousDay(DateTime currentDate) async {
    DateTime previousDate = currentDate.onlyDate().subtract(
          const Duration(days: 1),
        );
    if (previousDate.weekday == DateTime.sunday) {
      previousDate = previousDate.subtract(const Duration(days: 2));
    }
    final pedidos = utils.calendar[previousDate.ddMMyyyy()] ?? [];
    setDay({previousDate: pedidos});
    utils.focusedDay = previousDate;
    utilsStream.update();
  }

  void onAccept(
    StepModel step,
    PedidoModel pedido,
    int index, {
    bool auto = false,
  }) async {
    // Renova o lock para cobrir o gap do await
    _dropTimer?.cancel();
    _pendingDrop = true;

    if (!await onWillAccept(pedido, step, auto: auto)) {
      // Validação falhou — inicia timer para liberar lock
      _dropTimer?.cancel();
      _dropTimer = Timer(const Duration(milliseconds: 3000), () {
        _pendingDrop = false;
      });
      return;
    }

    final stepAnterior = pedido.step;
    final int indexAnterior = pedido.index;

    _onMovePedido(pedido, step, index);
    utilsStream.update();

    // Mantém lock ativo enquanto a persistência cirúrgica é executada
    _dropTimer?.cancel();
    _pendingDrop = true;

    // Executa a persistência cirúrgica com verificação de sucesso
    final salvou = await _onAddStep(pedido, step);
    if (!salvou) {
      log('[Kanban] Falha ao persistir movimento de ${pedido.localizador}. Executando rollback para ${stepAnterior.name}.');

      // Rollback nos steps e históricos adicionados em memória
      if (pedido.steps.isNotEmpty && pedido.steps.last.step.id == step.id) {
        pedido.steps.removeLast();
      }
      if (pedido.histories.isNotEmpty) {
        pedido.histories.removeLast();
      }

      // Devolve para a etapa e posição anteriores na UI
      _onMovePedido(pedido, stepAnterior, indexAnterior);
      utilsStream.update();

      _dropTimer?.cancel();
      _dropTimer = Timer(const Duration(milliseconds: 2000), () {
        _pendingDrop = false;
      });

      NotificationService.showNegative(
        'Falha ao mover pedido',
        'Não foi possível salvar a alteração de "${pedido.localizador}" no servidor. O cartão foi restaurado.',
      );
      return;
    }

    // Renova timer de proteção pós-drop bem-sucedido
    _dropTimer?.cancel();
    _dropTimer = Timer(const Duration(milliseconds: 3000), () {
      _pendingDrop = false;
    });

    // Process secondary actions in background
    onRemovePedidoFromPrioridadeIfNeeded(step, pedido);
    _getPedidosVinculadosToMove(pedido, step).then((pedidosVinculados) {
      if (pedidosVinculados.isNotEmpty) {
        onMovePedidosVinculados(step, pedidosVinculados);
        utilsStream.update();
      }
    });

    // Audit — só registra se mudou de etapa e foi persistido com sucesso
    if (stepAnterior.id != step.id && !auto) {
      AuditService.registrar(
        acao: 'mover_etapa',
        modulo: 'pedido',
        entidadeId: pedido.id,
        entidadeLabel: pedido.localizador,
        detalhes: {
          'de': stepAnterior.name,
          'para': step.name,
        },
      );
    }
  }

  /// Verifica se o Shift está pressionado no momento
  bool get _isShiftPressed =>
      HardwareKeyboard.instance.logicalKeysPressed
          .contains(LogicalKeyboardKey.shiftLeft) ||
      HardwareKeyboard.instance.logicalKeysPressed
          .contains(LogicalKeyboardKey.shiftRight);

  /// Exibe dialog pedindo e-mail e senha de um usuário administrador
  Future<bool> _pedirSenhaAdmin(String motivoBloqueio) async {
    final emailController = TextEditingController();
    final senhaController = TextEditingController();
    final focusSenha = FocusNode();

    void tentarAutorizar(BuildContext ctx) {
      final email = emailController.text.trim();
      final senha = senhaController.text.trim();
      if (email.isEmpty || senha.isEmpty) {
        NotificationService.showNegative(
          'Campos obrigatórios',
          'Preencha e-mail e senha.',
        );
        return;
      }
      final admin = FirestoreClient.usuarios.data.firstWhereOrNull(
        (u) => u.isAdmin &&
            u.email.toLowerCase().trim() == email.toLowerCase().trim() &&
            u.senha == senha,
      );
      if (admin != null) {
        Navigator.pop(ctx, true);
      } else {
        NotificationService.showNegative(
          'Credenciais inválidas',
          'E-mail ou senha incorretos, ou o usuário não é administrador.',
        );
      }
    }

    final result = await showDialog<bool>(
      context: contextGlobal,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.admin_panel_settings,
                size: 22, color: Colors.orange[700]),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Autenticação Admin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Motivo do bloqueio
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.20)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      motivoBloqueio,
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Entre com as credenciais de um administrador:',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 12),
              // Campo E-mail
              TextField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onSubmitted: (_) => focusSenha.requestFocus(),
              ),
              const SizedBox(height: 12),
              // Campo Senha
              TextField(
                controller: senhaController,
                focusNode: focusSenha,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onSubmitted: (_) => tentarAutorizar(ctx),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            onPressed: () => tentarAutorizar(ctx),
            label: const Text('Autorizar'),
          ),
        ],
      ),
    );
    if (result == true) {
      NotificationService.showPending(
        'Movimentação forçada',
        motivoBloqueio,
      );
    }
    return result ?? false;
  }

  /// Tenta autorizar override: se já é admin, mostra dialog de confirmação.
  /// Se não é admin, pede credenciais de admin.
  Future<bool> _tentarOverrideAdmin(String motivoBloqueio) async {
    if (usuario.isAdmin) {
      final confirmado = await showDialog<bool>(
        context: contextGlobal,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, size: 28, color: Colors.orange[700]),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Movimentação forçada',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.20)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        motivoBloqueio,
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange[800]),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Text(
                  'Deseja forçar esta movimentação?',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );
      return confirmado ?? false;
    }
    return _pedirSenhaAdmin(motivoBloqueio);
  }

  Future<bool> onWillAccept(PedidoModel pedido, StepModel step, {bool auto = false}) async {
    if (pedido.step.id != step.id) {
      // Regra de Aceite sem Elementos (válida para CD e CDA)
      final isCDorCDA =
          pedido.tipo == PedidoTipo.cd || pedido.tipo == PedidoTipo.cda;

      if (isCDorCDA && !step.isAcceptWithoutElements && pedido.elementos.isEmpty) {
        if (_isShiftPressed) {
          final autorizado = await _tentarOverrideAdmin(
            'Etapa não aceita pedidos CD/CDA sem elementos.');
          if (!autorizado) return false;
        } else {
          NotificationService.showNegative(
            'Operação não permitida',
            'Esta etapa não aceita pedidos CD/CDA sem elementos cadastrados.',
          );
          return false;
        }
      }

      // Regra de Aceite sem Endereço (todos os tipos de pedido)
      if (!step.isAcceptSemEndereco) {
        final endereco = pedido.obra.endereco;
        final temCoordenadas =
            endereco != null && (endereco.lat != 0 || endereco.lon != 0);
        final temEnderecoValidado =
            endereco != null && endereco.localidade.isNotEmpty;

        if (!temCoordenadas && !temEnderecoValidado) {
          if (_isShiftPressed) {
            final autorizado = await _tentarOverrideAdmin(
              'Etapa exige endereço ou coordenadas na obra.');
            if (!autorizado) return false;
          } else {
            NotificationService.showNegative(
              'Endereço obrigatório',
              'Esta etapa exige endereço ou coordenadas na obra do pedido.',
            );
            return false;
          }
        }
      }

      // Regra de Aceite sem Data de Entrega (todos os tipos de pedido)
      if (!step.isAcceptSemDataEntrega && pedido.deliveryAt == null) {
        if (_isShiftPressed) {
          final autorizado = await _tentarOverrideAdmin(
            'Etapa exige data de entrega cadastrada.');
          if (!autorizado) return false;
        } else {
          NotificationService.showNegative(
            'Data de entrega obrigatória',
            'Esta etapa exige uma data de entrega cadastrada no pedido.',
          );
          return false;
        }
      }

      // Regra de Aceite sem Pedido Financeiro (todos os tipos de pedido)
      if (!step.isAcceptSemPedidoFinanceiro &&
          pedido.pedidoFinanceiro.trim().isEmpty) {
        if (_isShiftPressed) {
          final autorizado = await _tentarOverrideAdmin(
            'Etapa exige pedido financeiro preenchido.');
          if (!autorizado) return false;
        } else {
          NotificationService.showNegative(
            'Pedido financeiro obrigatório',
            'Esta etapa exige o número do pedido financeiro preenchido no pedido.',
          );
          return false;
        }
      }

      final isStepAvailable =
          step.fromSteps.map((e) => e.id).contains(pedido.step.id);
      if (!isStepAvailable) {
        if (_isShiftPressed) {
          final autorizado = await _tentarOverrideAdmin(
            'Etapa de origem não permite mover para esta etapa.');
          if (!autorizado) return false;
        } else {
          NotificationService.showNegative(
            'Operação não permitida',
            'Etapa não aceita esta operação',
          );
          return false;
        }
      }
    }
    if (!auto) {
      final destAllowed = step.moveRoles.isEmpty ||
          step.moveRoles.contains(usuario.usuarioTipoId);
      final origAllowed = pedido.step.moveRoles.isEmpty ||
          pedido.step.moveRoles.contains(usuario.usuarioTipoId);

      if (!destAllowed || !origAllowed) {
        if (_isShiftPressed) {
          final autorizado = await _tentarOverrideAdmin(
            'Usuário sem permissão para mover nesta etapa.');
          if (!autorizado) return false;
        } else {
          NotificationService.showNegative(
            'Operação não permitida',
            'Usuário não tem permissão para alterar essa etapa',
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<bool> _onAddStep(PedidoModel pedido, StepModel step) async {
    pedidoCtrl.onAddHistory(
      pedido: pedido,
      data: step,
      type: PedidoHistoryType.step,
      action: PedidoHistoryAction.update,
    );

    // Garante que o step está registrado no pedido sem duplicar
    if (pedido.steps.isEmpty || pedido.steps.last.step.id != step.id) {
      pedido.addStep(step);
    }

    // ─── Correção: status travado após sair da produção ──────────────────────
    // Quando o pedido é movido manualmente para além do step de produção CDA
    // (ex: Expedição, Entrega), o campo `status` pode ter ficado travado em
    // `aguardandoProducaoCDA` ou `produzindoCDA` porque apenas a automação
    // e o ordemCtrl atualizam esse campo — nunca o Kanban.
    // Aqui forçamos o status para `pronto` quando o pedido avança além do
    // step de `aguardandoArmacaoPedido` configurado na automação.
    _corrigirStatusSeNecessario(pedido, step);

    BackendClient.pedidos.pedidosUnarchivedsStream.update();

    // Persiste cirurgicamente step_id, index, status e histories
    final resultado = await BackendClient.pedidos.updateStep(pedido, step);
    return resultado != null;
  }

  /// Força o status do pedido para `pronto` quando ele avança manualmente
  /// para além da etapa de produção CDA (ex: drag para Expedição ou Entrega).
  /// Evita que o pedido continue aparecendo na fila de armação.
  void _corrigirStatusSeNecessario(PedidoModel pedido, StepModel novoStep) {
    // Só aplica a pedidos que passam pela produção CDA
    if (pedido.tipo != PedidoTipo.cda) return;

    // Statuses que indicam que o pedido ainda "pertence" à fila de produção CDA
    const statusesDeProducao = {
      PedidoStatus.aguardandoProducaoCDA,
      PedidoStatus.produzindoCDA,
    };
    if (!statusesDeProducao.contains(pedido.status)) return;

    // Verifica se o novo step está além do step de aguardando armação
    final stepAguardandoArmacao =
        automatizacaoConfig.aguardandoArmacaoPedido.step;
    if (stepAguardandoArmacao == null) return;
    if (novoStep.index <= stepAguardandoArmacao.index) return;

    // O pedido saiu da produção CDA — força status = pronto
    log('[Kanban] Pedido ${pedido.localizador} saiu da produção CDA '
        '(status=${pedido.status.name}) ao mover para "${novoStep.name}". '
        'Forçando status → pronto.');

    final novoStatusModel = PedidoStatusModel.create(PedidoStatus.pronto);
    pedido.statusess.add(novoStatusModel);
  }

  void _onMovePedido(PedidoModel pedido, StepModel step, int index) {
    final originalStepId = pedido.step.id;
    final isSameStep = originalStepId == step.id;
    
    int originalIndex = -1;
    if (isSameStep) {
      final key = utils.kanban.keys.firstWhereOrNull((e) => e.id == originalStepId);
      if (key != null) {
        originalIndex = utils.kanban[key]!.indexOf(pedido);
      }
    }

    final removedPedido = _onRemovePedidoFromStep(originalStepId, pedido.id);
    if (removedPedido != null) {
      int finalIndex = index;
      if (isSameStep && originalIndex != -1 && originalIndex < index) {
        finalIndex = index - 1;
      }
      _onAddPedidoFromStep(
        step.id,
        finalIndex,
        pedido: removedPedido,
      );
      _onUpdatePedidosIndex(step.id, removedPedido.id);
    }
  }

  PedidoModel? _onRemovePedidoFromStep(String stepId, String pedidoId) {
    final key = utils.kanban.keys.firstWhereOrNull((e) => e.id == stepId);
    if (key == null) return null;
    final pedido = utils.kanban[key]?.firstWhereOrNull((e) => e.id == pedidoId);
    if (pedido != null) {
      utils.kanban[key]!.remove(pedido);
    }
    return pedido;
  }

  void _onAddPedidoFromStep(
    String stepId,
    int index, {
    required PedidoModel pedido,
  }) {
    final key = utils.kanban.keys.firstWhereOrNull((e) => e.id == stepId);
    if (key == null) return;
    
    if (index > utils.kanban[key]!.length) {
      index = utils.kanban[key]!.length;
    }
    
    utils.kanban[key]!.insert(index, pedido);
    pedido.addStep(key);
  }

  void _onUpdatePedidosIndex(String stepId, String movingPedidoId) {
    final key = utils.kanban.keys.firstWhereOrNull((e) => e.id == stepId);
    if (key == null) return;
    List<PedidoModel> pedidos = utils.kanban[key]!;

    // Atualiza os Ã­ndices locais
    for (int i = 0; i < pedidos.length; i++) {
      pedidos[i].index = i;
    }

    // Filtra os pedidos que NÃƒO sÃ£o o que acabou de se mover
    // (pois este jÃ¡ terÃ¡ um update individual via _onAddStep)
    final otherPedidos = pedidos.where((p) => p.id != movingPedidoId).toList();
    if (otherPedidos.isNotEmpty) {
      BackendClient.pedidos.updateAll(otherPedidos);
    }
  }

  void onListenerSrollEnd(BuildContext context, Offset mouse) {
    Alignment? align = _getAlignByPosition(context, mouse);
    if (align == null && utils.timer != null) {
      utils.cancelTimer();
    } else if (align != null && utils.timer == null) {
      _setTimerByAlign(align);
    }
  }

  Future<List<PedidoModel>> _getPedidosVinculadosToMove(
      PedidoModel pedido, StepModel step) async {
    final pedidosVinculados = pedido.getPedidosVinculados();
    final pedidosVinculadosFiltrados =
        pedidosVinculados.where((p) => p.step.id != step.id).toList();
    if (pedidosVinculadosFiltrados.isNotEmpty) {
      final pedidosSelecionados =
          await showPedidosVinculadosMoveSelectDialog(pedido, step);
      if (pedidosSelecionados != null && pedidosSelecionados.isNotEmpty) {
        return pedidosSelecionados;
      }
    }
    return [];
  }

  void onMovePedidosVinculados(StepModel step, List<PedidoModel> pedidos) {
    for (PedidoModel pedido in pedidos) {
      onAccept(step, pedido, 0, auto: true);
    }
  }

  Future<void> onRemovePedidoFromPrioridadeIfNeeded(
    StepModel step,
    PedidoModel pedido,
  ) async {}

  Alignment? _getAlignByPosition(BuildContext context, Offset mouse) {
    const gap = 200;
    final maxWidth =
        (MediaQuery.of(context).size.width + utils.scroll.offset) - gap;
    final minWidth = gap + utils.scroll.offset;
    final dx = mouse.dx + utils.scroll.offset;
    if (dx >= maxWidth) {
      return Alignment.centerRight;
    } else if (dx < minWidth) {
      return Alignment.centerLeft;
    } else {
      return null;
    }
  }

  void _setTimerByAlign(Alignment align) {
    if (align == Alignment.centerRight) {
      utils.timer = Timer.periodic(
        const Duration(milliseconds: 300),
        (timer) => _updateScrollSteps(utils.scroll.offset + 100),
      );
    } else {
      utils.timer = Timer.periodic(
        const Duration(milliseconds: 300),
        (timer) => _updateScrollSteps(utils.scroll.offset - 100),
      );
    }
  }

  void _updateScrollSteps(double offset) {
    utils.scroll.animateTo(
      offset,
      curve: Curves.ease,
      duration: const Duration(milliseconds: 300),
    );
  }

  void onUndoStep(PedidoModel pedido) async {
    if (pedido.steps.length < 2) return;
    final step = pedido.steps[pedido.steps.length - 2].step;
    if (!await showConfirmDialog(
      'Deseja voltar para etapa anterior?',
      'Seu pedido serÃ¡ movido para ${step.name}',
    )) {
      return;
    }
    _onMovePedido(pedido, step, 0);
    await _onAddStep(pedido, step);
    utilsStream.update();
  }

  void onOrderPedidos(SortStepType? value, List<PedidoModel> pedidos) async {
    if (value != null) {
      switch (value) {
        case SortStepType.createdAtAsc:
          pedidos.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case SortStepType.createdAtDesc:
          pedidos.sort((b, a) => a.createdAt.compareTo(b.createdAt));
          break;
        case SortStepType.localizador:
          pedidos.sort((a, b) => a.localizador.compareTo(b.localizador));
          break;
        case SortStepType.deliveryAtDesc:
          pedidos.sort((a, b) {
            if (a.deliveryAt == null && b.deliveryAt == null) {
              return 0;
            } else if (a.deliveryAt == null) {
              return 1;
            } else if (b.deliveryAt == null) {
              return -1;
            } else {
              return a.deliveryAt!.compareTo(b.deliveryAt!);
            }
          });
          break;
        case SortStepType.deliveryAtAsc:
          pedidos.sort((a, b) {
            if (a.deliveryAt == null && b.deliveryAt == null) {
              return 0;
            } else if (a.deliveryAt == null) {
              return 1;
            } else if (b.deliveryAt == null) {
              return -1;
            } else {
              return b.deliveryAt!.compareTo(a.deliveryAt!);
            }
          });
          break;
      }
      for (var i = 0; i < pedidos.length; i++) {
        pedidos[i].index = i;
      }
      await BackendClient.pedidos.updateAll(pedidos);
      utilsStream.update();
    }
  }
}
