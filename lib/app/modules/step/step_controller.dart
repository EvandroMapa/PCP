import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/enums/automatizacao_enum.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/step/step_view_model.dart';
import 'package:overlay_support/overlay_support.dart';

final stepCtrl = StepController();
StepModel get step => stepCtrl.step!;

class StepController {
  static final StepController _instance = StepController._();

  StepController._();

  factory StepController() => _instance;

  final AppStream<StepModel?> stepStream = AppStream<StepModel?>.seed(null);
  StepModel? get step => stepStream.value;

  final AppStream<StepUtils> utilsStream = AppStream<StepUtils>.seed(
    StepUtils(),
  );
  StepUtils get utils => utilsStream.value;

  void onInit() {
    utilsStream.add(StepUtils());
    FirestoreClient.steps.fetch();
  }

  final AppStream<StepCreateModel> formStream = AppStream<StepCreateModel>();
  StepCreateModel get form => formStream.value;

  void init(StepModel? step) {
    formStream.add(
      step != null ? StepCreateModel.edit(step) : StepCreateModel(),
    );
  }

  List<StepModel> getStepesFiltered(String search, List<StepModel> steps) {
    if (search.length < 3) return steps;
    List<StepModel> filtered = [];
    for (final step in steps) {
      if (step.toString().toCompare.contains(search.toCompare)) {
        filtered.add(step);
      }
    }
    return filtered;
  }

  Future<void> onConfirm(value, StepModel? step) async {
    try {
      onValid();
      final newStep = form.toStepModel(step);

      if (form.isEdit) {
        await FirestoreClient.steps.update(newStep);
      } else {
        await FirestoreClient.steps.add(newStep);
      }
      if (newStep.isDefault) {
        await FirestoreClient.steps.setDefault(newStep.id);
      }
      pop(value);
      NotificationService.showPositive(
        'Step ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
      await FirestoreClient.steps.fetch();
    } catch (e) {
      NotificationService.showNegative(
        'Erro',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> onDelete(value, StepModel step) async {
    if (await _isDeleteUnavailable(step)) return;
    await FirestoreClient.steps.delete(step);
    pop(value);
    NotificationService.showPositive(
      'Step Excluido',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );
    await FirestoreClient.steps.fetch();
  }

  Future<bool> _isDeleteUnavailable(StepModel step) async {
    // Proteção 1: Verifica se o step está vinculado a alguma regra de automação
    // (tanto como step único quanto dentro de uma lista de steps)
    final automatizacao = BackendClient.automatizacao.data;
    final regrasVinculadas = <String>[];

    for (final item in automatizacao.itens) {
      final emStepUnico = item.step?.id == step.id;
      final emListaSteps = item.steps?.any((s) => s.id == step.id) ?? false;
      if (emStepUnico || emListaSteps) {
        regrasVinculadas.add(item.type.label);
      }
    }

    if (regrasVinculadas.isNotEmpty) {
      NotificationService.showNegative(
        'Etapa em uso na Automação',
        'Esta etapa está configurada em: ${regrasVinculadas.join(', ')}. '
        'Remova-a das regras de automação antes de excluir.',
        position: NotificationPosition.bottom,
      );
      return true;
    }

    // Proteção 2: Verifica se há pedidos vinculados à etapa
    return !await onDeleteProcess(
      deleteTitle: 'Deseja excluir a etapa?',
      deleteMessage: 'Todos os dados da etapa serão excluidos do sistema',
      infoMessage:
          'Para excluir a etapa, nenhum pedido pode estar vinculado a ela',
      conditional: !FirestoreClient.pedidos.data.every(
        (e) => e.step.id != step.id,
      ),
    );
  }

  void onValid() {
    String name = form.name.text.trim();
    if (name.isEmpty) {
      throw Exception('Nome não pode ser vazio');
    }
    if (form.isEdit) {
      if (FirestoreClient.steps.data.any((e) =>
          e.name.toLowerCase().trim() == name.toLowerCase() &&
          e.id.toString().trim() != form.id.toString().trim())) {
        throw Exception('Já existe uma etapa com esse nome');
      }
    } else {
      if (FirestoreClient.steps.data
          .any((e) => e.name.toLowerCase().trim() == name.toLowerCase())) {
        throw Exception('Já existe uma etapa com esse nome');
      }
    }
  }

  List<int> getSteps(int? pos) {
    final positions = [0, 1, 2, 3, 4, 5, 6];
    positions.sort((a, b) => a.compareTo(b));
    return positions;
  }
}
