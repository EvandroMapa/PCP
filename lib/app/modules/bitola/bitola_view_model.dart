import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/extensions/text_controller_ext.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class BitolaUtils {
  final TextController search = TextController();
}

class BitolaCreateModel {
  final String id;
  TextController nome = TextController();
  TextController descricao = TextController();
  TextController massaFinal = TextController.number();
  TextController codigoFinanceiro = TextController();
  FabricanteModel? fabricante;
  int sortIndex = 999;
  late bool isEdit;

  BitolaCreateModel()
      : id = HashService.get,
        isEdit = false;

  BitolaCreateModel.edit(BitolaModel produto)
      : id = produto.id,
        isEdit = true {
    nome.text = produto.nome;
    descricao.text = produto.descricao;
    massaFinal = TextController.number(value: produto.massaFinal);
    codigoFinanceiro.text = produto.codigoFinanceiro;
    sortIndex = produto.sortIndex;
  }

  BitolaModel toBitolaModel() => BitolaModel(
        id: id,
        nome: nome.text,
        descricao: descricao.text,
        massaFinal: massaFinal.doubleValue,
        codigoFinanceiro: codigoFinanceiro.text,
        sortIndex: sortIndex,
      );
}
