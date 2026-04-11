import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

final signCtrl = SignController();

class SignController {
  static final SignController _instance = SignController._();

  SignController._();

  factory SignController() => _instance;

  final GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  void onClickLogin(String email, String senha, bool rememberMe) {
    try {
      final user = BackendClient.usuarios.data.firstWhereOrNull(
        (e) =>
            e.email.toCompare == email.toCompare &&
            e.senha.toCompare == senha.toCompare,
      );
      if (user == null) throw Exception('Usuário não encontrado');

      usuarioCtrl.setCurrentUser(user, rememberMe);
    } catch (value) {
      NotificationService.showNegative('Erro', value.toString());
    }
  }
}
