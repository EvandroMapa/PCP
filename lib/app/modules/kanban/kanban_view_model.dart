import 'dart:async';

import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:flutter/material.dart';

import 'package:table_calendar/table_calendar.dart';

enum KanbanViewMode { calendar, kanban }

class KanbanUtils {
  KanbanViewMode view = KanbanViewMode.kanban;
  CalendarFormat calendarFormat = CalendarFormat.week;
  Map<StepModel, List<PedidoModel>> kanban;
  Map<String, List<PedidoModel>> calendar;
  Map<DateTime, List<PedidoModel>>? day;

  /// Quando a lista aberta não é de um dia (ex.: "Atrasados", "Sem data")
  String? listaTitulo;
  final ScrollController scroll = ScrollController();
  PedidoModel? pedido;
  bool get isPedidoSelected => pedido != null;
  bool get isDaySelected => day != null;
  TextController search = TextController();
  ClienteModel? cliente;
  TextController clienteEC = TextController();
  Timer? timer;

  DateTime focusedDay = DateTime.now();
  UsuarioModel? usuario;
  TextController usuarioEC = TextController();
  PageController? pageController;
  TextController localidadeEC = TextController();
  List<TagModel> tagsSelecionadas = [];
  TextController tagEC = TextController();

  // Filtros rápidos (quadro e calendário)
  bool soAtrasados = false;
  bool soSemData = false;

  /// Entrega vencida e ainda não entregue
  static bool isAtrasado(PedidoModel pedido) {
    if (pedido.deliveryAt == null || pedido.isEntregue) return false;
    final now = DateTime.now();
    return pedido.deliveryAt!.isBefore(DateTime(now.year, now.month, now.day));
  }

  void cancelTimer() {
    if (timer?.isActive ?? false) {
      timer?.cancel();
      timer = null;
    }
  }

  int getFilterSteps() {
    int qtde = 0;
    if (search.text.isNotEmpty) {
      qtde++;
    }
    if (cliente != null) {
      qtde++;
    }
    if (usuario != null) {
      qtde++;
    }
    if (localidadeEC.text.isNotEmpty) {
      qtde++;
    }
    if (tagsSelecionadas.isNotEmpty) {
      qtde++;
    }
    if (usuarioEC.text.isNotEmpty) {
      qtde++;
    }
    if (soAtrasados) qtde++;
    if (soSemData) qtde++;
    return qtde;
  }

  bool hasFilter() =>
      search.text.isNotEmpty ||
      cliente != null ||
      usuario != null ||
      localidadeEC.text.isNotEmpty ||
      tagsSelecionadas.isNotEmpty ||
      usuarioEC.text.isNotEmpty ||
      soAtrasados ||
      soSemData;

  /// [ignorarRapidos] serve para contar quantos atrasados / sem data
  /// existem dentro dos outros filtros
  bool isPedidoVisibleFiltered(PedidoModel pedido,
      {bool ignorarRapidos = false}) {
    if (!hasFilter()) return true;
    if (!ignorarRapidos) {
      if (soAtrasados && !isAtrasado(pedido)) return false;
      if (soSemData && pedido.deliveryAt != null) return false;
    }
    if (search.text.isNotEmpty) {
      if (!pedido.filtro.toCompare.contains(search.text.toCompare)) {
        return false;
      }
    }
    if (cliente != null) {
      if (pedido.cliente.id != cliente!.id) return false;
    }
    if (usuario != null) {
      if (!pedido.users.any((user) => user.id == usuario!.id)) {
        return false;
      }
    }
    if (localidadeEC.text.isNotEmpty) {
      if (!(pedido.obra.endereco?.localidade.toCompare.contains(
            localidadeEC.text.toCompare,
          ) ??
          false)) {
        return false;
      }
    }
    if (tagsSelecionadas.isNotEmpty) {
      if (!pedido.tags.any((t) => tagsSelecionadas.any((s) => s.id == t.id))) {
        return false;
      }
    }
    return true;
  }

  KanbanUtils({required this.kanban, required this.calendar});
}
