import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class FabricanteUtils {
  final TextController search = TextController();
}

class FabricanteCreateModel {
  final String id;
  TextController nome = TextController();
  TextController descricao = TextController();
  TextController contato = TextController();
  TextController telefone = TextController();
  TextController email = TextController();
  late bool isEdit;

  FabricanteCreateModel()
      : id = HashService.get,
        isEdit = false;

  FabricanteCreateModel.edit(FabricanteModel fabricante)
      : id = fabricante.id,
        isEdit = true {
    nome.text = fabricante.nome;
    descricao.text = fabricante.descricao ?? '';
    contato.text = fabricante.contato ?? '';
    telefone.text = fabricante.telefone ?? '';
    email.text = fabricante.email ?? '';
  }

  FabricanteModel toFabricanteModel() => FabricanteModel(
        id: id,
        nome: nome.text,
        descricao: descricao.text.isEmpty ? null : descricao.text,
        contato: contato.text.isEmpty ? null : contato.text,
        telefone: telefone.text.isEmpty ? null : telefone.text,
        email: email.text.isEmpty ? null : email.text,
      );
}
