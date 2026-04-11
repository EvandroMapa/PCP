import 'dart:developer';
import 'dart:async';
import 'package:collection/collection.dart';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/enums/sort_step_type.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedidos_vinculados_move_select_dialog.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/usuario_role.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';
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
  Timer? _refreshTimer;


  void startDrag() => isDragging = true;
  void endDrag() {
    isDragging = false;
    // NÃO faz fetch imediato — o estado local já está correto (optimistic).
    // Agenda um fetch com delay para dar tempo do update() no Supabase terminar
    // antes de re-sincronizar os dados com o backend.
    _pendingDrop = true;
    Future.delayed(const Duration(milliseconds: 1500), () {
      _pendingDrop = false;
      BackendClient.pedidos.fetch();
    });
  }

  Future<void> onInit() async {
    try {
      _pedidosSubscription?.cancel();
      _pedidosSubscription = BackendClient.pedidos.dataStream.listen.listen((_) {
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

      // Timer de atualização automática a cada 3 segundos
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!isDropLocked) {
          BackendClient.pedidos.fetch();
        }
      });

      onMount();
    } catch (e) {
      log('StepController: Erro no onInit', error: e);
    }
  }

  void onMount() async {
    final kanban = mountKanban();
    final calendar = _mountCalendar();
    utils.calendar = calendar;
    utils.kanban = kanban;
    utilsStream.update();
  }

  Map<StepModel, List<PedidoModel>> mountKanban() {
    try {
      final pedidos = BackendClient.pedidos.pepidosUnarchiveds.toList();
      final kanban = <StepModel, List<PedidoModel>>{};
      final stepsData = BackendClient.steps.data.toList();
      
      if (stepsData.isEmpty) return kanban;

      for (StepModel step in stepsData) {
        final pedidosStep = pedidos.where((e) => e.step.id == step.id).toList();
        
        // Proteção contra index nulo ou erros de comparação
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
    
    // Filtramos apenas pedidos não arquivados que têm data de entrega
    final pedidosCalendario = BackendClient.pedidos.pepidosUnarchiveds
        .where((e) => e.deliveryAt != null)
        .toList();

    for (final pedido in pedidosCalendario) {
      // Formata a data de entrega ignorando o horário, apenas dia, mês e ano
      final diaKey = DateFormat('dd/MM/yyyy').format(pedido.deliveryAt!);
      
      if (!calendar.containsKey(diaKey)) {
        calendar[diaKey] = [];
      }
      calendar[diaKey]!.add(pedido);
    }
    
    return calendar;
  }

  void updateKanban() {
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
    if (!onWillAccept(pedido, step, auto: auto)) return;
    _onMovePedido(pedido, step, index);
    utilsStream.update();
    
    // Process secondary actions in background
    _onAddStep(pedido, step);
    onRemovePedidoFromPrioridadeIfNeeded(step, pedido);
    _getPedidosVinculadosToMove(pedido, step).then((pedidosVinculados) {
      if (pedidosVinculados.isNotEmpty) {
        onMovePedidosVinculados(step, pedidosVinculados);
        utilsStream.update();
      }
    });
  }

  bool onWillAccept(PedidoModel pedido, StepModel step, {bool auto = false}) {
    if (pedido.step.id != step.id) {
      final isStepAvailable = step.fromSteps
          .map((e) => e.id)
          .contains(pedido.step.id);
      if (!isStepAvailable) {
        NotificationService.showNegative(
          'Operação não permitida',
          'Etapa não aceita esta operação',
        );
        return false;
      }
    }
    if (!auto) {
      final isAdmin = usuario.role == UsuarioRole.administrador;
      final destAllowed = step.moveRoles.isEmpty || step.moveRoles.contains(usuario.role);
      final origAllowed = pedido.step.moveRoles.isEmpty || pedido.step.moveRoles.contains(usuario.role);
      
      if (!isAdmin && (!destAllowed || !origAllowed)) {
        NotificationService.showNegative(
          'Operação não permitida',
          'Usuário não tem permissão para alterar essa etapa',
        );
        return false;
      }
    }
    return true;
  }

  void _onAddStep(PedidoModel pedido, StepModel step) async {
    pedidoCtrl.onAddHistory(
      pedido: pedido,
      data: step,
      type: PedidoHistoryType.step,
      action: PedidoHistoryAction.update,
    );
    pedido.addStep(step);
    BackendClient.pedidos.pedidosUnarchivedsStream.update();
    // A chamada de update aqui já persiste a nova etapa e o novo índice do pedido
    // Não usamos await para não travar a UI
    BackendClient.pedidos.update(pedido);
  }

  void _onMovePedido(PedidoModel pedido, StepModel step, int index) {
    final removedPedido = _onRemovePedidoFromStep(pedido.step.id, pedido.id);
    if (removedPedido != null) {
      _onAddPedidoFromStep(
        step.id,
        index,
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
    utils.kanban[key]!.insert(index, pedido);
    pedido.addStep(key);
  }

  void _onUpdatePedidosIndex(String stepId, String movingPedidoId) {
    final key = utils.kanban.keys.firstWhereOrNull((e) => e.id == stepId);
    if (key == null) return;
    List<PedidoModel> pedidos = utils.kanban[key]!;
    
    // Atualiza os índices locais
    for (int i = 0; i < pedidos.length; i++) {
      pedidos[i].index = i;
    }

    // Filtra os pedidos que NÃO são o que acabou de se mover 
    // (pois este já terá um update individual via _onAddStep)
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

  Future<List<PedidoModel>> _getPedidosVinculadosToMove(PedidoModel pedido, StepModel step) async {
    final pedidosVinculados = pedido.getPedidosVinculados();
    final pedidosVinculadosFiltrados = pedidosVinculados
        .where((p) => p.step.id != step.id)
        .toList();
    if (pedidosVinculadosFiltrados.isNotEmpty) {
      final pedidosSelecionados = await showPedidosVinculadosMoveSelectDialog(pedido, step);
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
  ) async {

  }


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
      'Seu pedido será movido para ${step.name}',
    )) {
      return;
    }
    _onMovePedido(pedido, step, 0);
    _onAddStep(pedido, step);
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
