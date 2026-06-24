import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class EquipamentoUtils {
  final TextController search = TextController();
}

class EquipamentoCreateModel {
  final String id;
  TextController codigo = TextController();
  TextController descricao = TextController();
  late bool isEdit;

  EquipamentoCreateModel()
      : id = HashService.get,
        isEdit = false;

  EquipamentoCreateModel.edit(EquipamentoModel equipamento)
      : id = equipamento.id,
        isEdit = true {
    codigo.text = equipamento.codigo;
    descricao.text = equipamento.descricao;
  }

  EquipamentoModel toEquipamentoModel() => EquipamentoModel(
        id: id,
        codigo: codigo.text,
        descricao: descricao.text,
      );
}
