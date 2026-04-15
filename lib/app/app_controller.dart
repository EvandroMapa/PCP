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
      await kanbanCtrl.onInit();
      pedidoCtrl.onInit();
      _setupCascadeListeners();
      if (key.currentState?.context != null) {
        precacheImage(
          const AssetImage('assets/images/kanban_background.png'),
          key.currentState!.context,
        );
      }
    } catch (e) {
      log('AppController: Erro no onInit: $e');
    }
  }

  Timer? _cascadeDebounce;

  /// Quando Fabricantes ou Produtos mudam, re-faz fetch de MatériasPrimas e Ordens
  /// para que o dynamic linking reconstrua os objetos com dados atualizados.
  void _setupCascadeListeners() {
    BackendClient.fabricantes.dataStream.listen.listen((_) {
      _triggerCascadeRefetch();
    });
    BackendClient.produtos.dataStream.listen.listen((_) {
      _triggerCascadeRefetch();
    });
  }

  void _triggerCascadeRefetch() {
    // Debounce de 500ms para evitar múltiplos fetches simultâneos
    _cascadeDebounce?.cancel();
    _cascadeDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        await BackendClient.materiaPrima.fetch();
        await BackendClient.ordens.fetch();
        log('AppController: Cascade refetch concluído (fabricantes/produtos → materias_primas/ordens)');
      } catch (e) {
        log('AppController: Erro no cascade refetch: $e');
      }
    });
  }
}
