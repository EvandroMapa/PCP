import 'package:aco_plus/app/core/enums/app_module.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

final baseCtrl = BaseController();

class BaseController {
  static final BaseController _instance = BaseController._();

  BaseController._();

  factory BaseController() => _instance;

  final GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  final AppStream<AppModule> moduleStream = AppStream<AppModule>();
  final AppStream<List<Widget>> appBarActionsStream =
      AppStream<List<Widget>>.seed([]);

  Future<void> onInit() async {
    _updateInitialModule();
    usuarioCtrl.usuarioStream.listen.listen((user) {
      if (user != null) {
        _updateInitialModule();
      }
    });
  }

  void _updateInitialModule() {
    AppModule initial = AppModule.values.first;
    if (usuario.isOperador) initial = AppModule.ordens;
    if (usuario.isArmador) initial = AppModule.armacao;
    moduleStream.add(initial);
  }
}
