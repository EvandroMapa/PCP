import 'dart:async';
import 'dart:developer';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

AppController appCtrl = AppController();

class AppController {
  static final AppController _instance = AppController._();

  AppController._();

  factory AppController() => _instance;

  final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();
  BuildContext get context => key.currentState!.context;

  bool isInitialized = false;
  Future<void> onInit() async {
    try {
      if (isInitialized) return;
      isInitialized = true;
      usuarioCtrl.setup();
      await usuarioCtrl.getCurrentUser();
      // Não aguarda o kanban — carrega em background para não travar o startup
      kanbanCtrl.onInit();
      pedidoCtrl.onInit();
      _setupCascadeListeners();
    } catch (e) {
      log('AppController: Erro no onInit: $e');
    }
  }

  Timer? _cascadeDebounce;
  bool _isFirstLoad = true;

  /// Cascade reativo em 2 níveis:
  /// 1. Fabricantes/Produtos mudam → re-fetch MatériasPrimas + Ordens
  /// 2. MatériasPrimas mudam → re-fetch Ordens
  void _setupCascadeListeners() {
    // Nível 1: Fabricantes ou Produtos → MatériasPrimas + Ordens
    BackendClient.fabricantes.dataStream.listen.listen((_) {
      if (_isFirstLoad) return; // Ignora carga inicial
      _triggerFullCascade();
    });
    BackendClient.bitolas.dataStream.listen.listen((_) {
      if (_isFirstLoad) return;
      _triggerFullCascade();
    });

    // Nível 2: MatériasPrimas → Ordens
    BackendClient.materiaPrima.dataStream.listen.listen((_) {
      if (_isFirstLoad) return;
      _triggerOrdensCascade();
    });

    // Marca fim da carga inicial após 3 segundos
    Timer(const Duration(seconds: 3), () {
      _isFirstLoad = false;
      log('AppController: Cascade listeners ativos');
    });
  }

  void _triggerFullCascade() {
    _cascadeDebounce?.cancel();
    _cascadeDebounce = Timer(const Duration(milliseconds: 2000), () async {
      try {
        await BackendClient.materiaPrima.fetch();
        await BackendClient.ordens.fetch();
        log('AppController: Full cascade concluído (fab/prod → mp → ordens)');
      } catch (e) {
        log('AppController: Erro no full cascade: $e');
      }
    });
  }

  Timer? _ordensDebounce;

  void _triggerOrdensCascade() {
    _ordensDebounce?.cancel();
    _ordensDebounce = Timer(const Duration(milliseconds: 2000), () async {
      try {
        await BackendClient.ordens.fetch();
        log('AppController: Ordens cascade concluído (mp → ordens)');
      } catch (e) {
        log('AppController: Erro no ordens cascade: $e');
      }
    });
  }
}
