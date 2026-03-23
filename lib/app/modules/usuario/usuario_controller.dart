import 'package:aco_plus/app/app_repository.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
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
    pop(value);
    NotificationService.showPositive(
      'Usuario Excluida',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );
  }

  void onValid() {
    if (form.nome.text.length < 2) {
      throw Exception('Nome deve conter no mínimo 3 caracteres');
    }
  }

  Future<void> getCurrentUser() async {
    UsuarioModel? user = await AppRepository.get();
    if (user != null &&
        BackendClient.usuarios.data.any((e) => e.id == user!.id)) {
      user = BackendClient.usuarios.getById(user!.id);
      AppRepository.add(user!);
    }

    // --- TEMPORARY BYPASS ---
    // Automatiscamente logo com evandro / 123 se não houver usuário.
    if (user == null) {
      final mock = BackendClient.usuarios.data.firstWhereOrNull(
        (e) => e.email.toLowerCase() == 'evandro' && e.senha == '123'
      );
      if (mock != null) {
        user = mock;
        AppRepository.add(user);
      }
    }
    // ------------------------
    usuarioStream.add(user);
  }

  Future<void> setCurrentUser(UsuarioModel usuario) async {
    await AppRepository.add(usuario);
    await getCurrentUser();
    FCMProvider.putToken();
  }

  Future<void> clearCurrentUser() async {
    usuario?.deviceTokens.removeWhere((e) => e == deviceToken);
    BackendClient.usuarios.update(usuario!);
    await AppRepository.clear();
    getCurrentUser();
  }
}
