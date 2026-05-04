import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class PatioUtils {
  final TextController search = TextController();
}

class PatioCreateModel {
  final String id;
  TextController nome = TextController();
  TextController comprimento = TextController();
  TextController largura = TextController();
  DateTime createdAt = DateTime.now();

  late bool isEdit;

  PatioCreateModel()
      : id = HashService.get,
        isEdit = false;

  PatioCreateModel.edit(PatioModel patio)
      : id = patio.id,
        isEdit = true {
    nome.text = patio.nome;
    comprimento.text = patio.comprimento > 0 ? patio.comprimento.toString() : '';
    largura.text = patio.largura > 0 ? patio.largura.toString() : '';
    createdAt = patio.createdAt;
  }

  int get comprimentoInt => int.tryParse(comprimento.text) ?? 0;
  int get larguraInt => int.tryParse(largura.text) ?? 0;

  PatioModel toPatioModel() => PatioModel(
        id: id,
        nome: nome.text,
        comprimento: comprimentoInt,
        largura: larguraInt,
        createdAt: createdAt,
      );
}
