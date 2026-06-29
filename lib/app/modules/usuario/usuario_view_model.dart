import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/usuario_role.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class UsuarioUtils {
  final TextController search = TextController();
  bool mostrarInativos = false;
}

class UsuarioCreateModel {
  final String id;
  TextController nome = TextController();
  TextController email = TextController();
  TextController senha = TextController();
  UsuarioRole? role;
  String usuarioTipoId = '';
  bool isAtivo = true;
  late bool isEdit;

  UsuarioCreateModel()
      : id = HashService.get,
        isEdit = false;

  UsuarioCreateModel.edit(UsuarioModel user)
      : id = user.id,
        isEdit = true {
    nome.text = user.nome;
    email.text = user.email;
    role = user.role;
    usuarioTipoId = user.usuarioTipoId;
    senha.text = user.senha;
    isAtivo = user.isAtivo;
  }

  UsuarioModel toUsuarioModel() => UsuarioModel(
        id: id,
        nome: nome.text,
        email: email.text,
        role: role ?? UsuarioRole.operador,
        usuarioTipoId: usuarioTipoId,
        senha: senha.text,
        steps: [],
        deviceTokens: [],
        isAtivo: isAtivo,
      );
}
