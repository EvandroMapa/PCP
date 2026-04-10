import 'dart:developer';
import 'package:aco_plus/app/app_repository.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/http/fcm/fcm_provider.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/push_notification_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/usuario/usuario_view_model.dart';
import 'package:collection/collection.dart';
import 'package:overlay_support/overlay_support.dart';

final usuarioCtrl = UsuarioController();
UsuarioModel get usuario => usuarioCtrl.usuario!;

class UsuarioController {
  static final UsuarioController _instance = UsuarioController._();

  UsuarioController._();

  factory UsuarioController() => _instance;
  
  void setup() {
    BackendClient.usuarios.dataStream.listen.listen((list) {
      if (usuario != null) {
        final match = list.firstWhereOrNull((e) => e.id == usuario!.id);
        if (match != null && match != usuario) {
          usuarioStream.add(match);
        }
      }
    });
  }

  final AppStream<UsuarioModel?> usuarioStream = AppStream<UsuarioModel?>.seed(
    null,
  );
  UsuarioModel? get usuario => usuarioStream.value;

  final AppStream<UsuarioUtils> utilsStream = AppStream<UsuarioUtils>.seed(
    UsuarioUtils(),
  );
  UsuarioUtils get utils => utilsStream.value;

  final AppStream<UsuarioCreateModel> formStream =
      AppStream<UsuarioCreateModel>();
  UsuarioCreateModel get form => formStream.value;

  void init(UsuarioModel? usuario) {
    formStream.add(
      usuario != null ? UsuarioCreateModel.edit(usuario) : UsuarioCreateModel(),
    );
  }

  List<UsuarioModel> getUsuariosFiltered(
    String search,
    List<UsuarioModel> usuarios,
  ) {
    if (search.length < 3) return usuarios;
    List<UsuarioModel> filtered = [];
    for (final usuario in usuarios) {
      if (usuario.toString().toCompare.contains(search.toCompare)) {
        filtered.add(usuario);
      }
    }
    return filtered;
  }

  Future<void> onConfirm(value, UsuarioModel? usuario) async {
    try {
      onValid();
      if (form.isEdit) {
        final edit = form.toUsuarioModel();
        await BackendClient.usuarios.update(edit);
      } else {
        await BackendClient.usuarios.add(form.toUsuarioModel());
      }
      pop(value);
      NotificationService.showPositive(
        'Usuário ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
      await BackendClient.usuarios.fetch();
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao realizar operação',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> onDelete(value, UsuarioModel usuario) async {
    await BackendClient.usuarios.delete(usuario);
    await BackendClient.usuarios.fetch();
    pop(value);
    NotificationService.showPositive(
      'Usuario Excluido',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );
  }

  void onValid() {
    String nomeForm = form.nome.text.trim();
    String emailForm = form.email.text.trim().toLowerCase();
    if (nomeForm.length < 2) {
      throw Exception('Nome deve conter no mínimo 3 caracteres');
    }
    if (emailForm.isEmpty) {
      throw Exception('Login inválido');
    }
    if (form.usuarioTipoId.isEmpty) {
      throw Exception('É obrigatório selecionar um Perfil de Acesso');
    }
    if (form.isEdit) {
      if (BackendClient.usuarios.data.any((e) =>
          e.email.toLowerCase().trim() == emailForm &&
          e.id.toString().trim() != form.id.toString().trim())) {
        throw Exception('Já existe um usuário com esse login');
      }
    } else {
      if (BackendClient.usuarios.data.any(
          (e) => e.email.toLowerCase().trim() == emailForm)) {
        throw Exception('Já existe um usuário com esse login');
      }
    }
  }

  Future<void> getCurrentUser() async {
    try {
      UsuarioModel? user = await AppRepository.get();
      if (user != null) {
        final usuariosData = BackendClient.usuarios.data;
        if (usuariosData.isNotEmpty && usuariosData.any((e) => e.id == user!.id)) {
          user = BackendClient.usuarios.getById(user!.id);
          AppRepository.add(user!);
        } else {
          user = null;
          await AppRepository.clear();
        }
      }
      usuarioStream.add(user);
    } catch (e) {
      log('UsuarioController: Erro no auto-login', error: e);
      usuarioStream.add(null);
    }
  }

  Future<void> setCurrentUser(UsuarioModel usuario, bool rememberMe) async {
    if (rememberMe) {
      await AppRepository.add(usuario);
    } else {
      await AppRepository.removeUser();
    }
    usuarioStream.add(usuario);
    FCMProvider.putToken();
  }

  Future<void> clearCurrentUser() async {
    usuario?.deviceTokens.removeWhere((e) => e == deviceToken);
    BackendClient.usuarios.update(usuario!);
    await AppRepository.removeUser();
    usuarioStream.add(null);
  }
}
