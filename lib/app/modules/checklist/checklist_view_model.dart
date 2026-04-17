import 'package:aco_plus/app/core/client/firestore/collections/checklist/models/checklist_model.dart';
import 'package:aco_plus/app/core/components/checklist/check_item_model.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class ChecklistUtils {
  final TextController search = TextController();
}

class ChecklistCreateModel {
  final String id;
  TextController nome = TextController();
  List<CheckItemModel> checklist = [];
  DateTime createdAt = DateTime.now();
  bool isPadrao = false;

  late bool isEdit;

  ChecklistCreateModel()
      : id = HashService.get,
        isEdit = false;

  ChecklistModel? _original;

  ChecklistCreateModel.edit(ChecklistModel tag)
      : id = tag.id,
        isEdit = true {
    _original = tag;
    checklist = tag.checklist.map((e) => e.copyWith()).toList();
    createdAt = tag.createdAt;
    nome.text = tag.nome;
    isPadrao = tag.isPadrao;
  }

  bool get isDirty {
    if (!isEdit) {
      return nome.text.isNotEmpty || checklist.isNotEmpty || isPadrao;
    }
    return toChecklistModel() != _original;
  }

  ChecklistModel toChecklistModel() => ChecklistModel(
        id: id,
        nome: nome.text,
        checklist: checklist,
        createdAt: createdAt,
        isPadrao: isPadrao,
      );
}
