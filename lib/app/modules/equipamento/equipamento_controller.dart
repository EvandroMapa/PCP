import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/equipamento/equipamento_view_model.dart';
import 'package:overlay_support/overlay_support.dart';

final equipamentoCtrl = EquipamentoController();

class EquipamentoController {
  static final EquipamentoController _instance = EquipamentoController._();

  EquipamentoController._();

  factory EquipamentoController() => _instance;

  final AppStream<EquipamentoUtils> utilsStream = AppStream<EquipamentoUtils>.seed(
    EquipamentoUtils(),
  );
  EquipamentoUtils get utils => utilsStream.value;

  void onInit() {
    utilsStream.add(EquipamentoUtils());
    BackendClient.equipamentos.listen();
  }

  final AppStream<EquipamentoCreateModel> formStream =
      AppStream<EquipamentoCreateModel>();
  EquipamentoCreateModel get form => formStream.value;

  void init(EquipamentoModel? equipamento) {
    formStream.add(
      equipamento != null
          ? EquipamentoCreateModel.edit(equipamento)
          : EquipamentoCreateModel(),
    );
  }

  List<EquipamentoModel> getEquipamentosFiltered(
    String search,
    List<EquipamentoModel> equipamentos,
  ) {
    if (search.length < 2) return equipamentos;
    List<EquipamentoModel> filtered = [];
    for (final equipamento in equipamentos) {
      if (equipamento.toString().toCompare.contains(search.toCompare)) {
        filtered.add(equipamento);
      }
    }
    return filtered;
  }

  Future<void> onConfirm(value, EquipamentoModel? equipamento) async {
    try {
      onValid(equipamento);
      if (form.isEdit) {
        final edit = form.toEquipamentoModel();
        await BackendClient.equipamentos.update(edit);
      } else {
        await BackendClient.equipamentos.add(form.toEquipamentoModel());
      }
      await BackendClient.equipamentos.fetch();
      pop(value);
      NotificationService.showPositive(
        'Equipamento ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> onDelete(value, EquipamentoModel equipamento) async {
    if (await _isDeleteUnavailable(equipamento)) return;
    await BackendClient.equipamentos.delete(equipamento);
    pop(value);
    NotificationService.showPositive(
      'Equipamento Excluído',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );

    AuditService.registrar(
      acao: 'excluir_equipamento',
      modulo: 'equipamento',
      entidadeId: equipamento.id,
      entidadeLabel: equipamento.descricao,
    );
  }

  Future<bool> _isDeleteUnavailable(
    EquipamentoModel equipamento,
  ) async =>
      !await onDeleteProcess(
        deleteTitle: 'Deseja excluir o equipamento?',
        deleteMessage: 'Todos seus dados serão apagados do sistema',
        infoMessage:
            'Não é possível excluir o equipamento, pois ele está vinculado a ordens de produção.',
        conditional: BackendClient.ordens.data.any(
          (e) => e.equipamento?.id == equipamento.id,
        ),
      );

  void onValid(EquipamentoModel? equipamento) {
    String descricaoForm = form.descricao.text.trim();
    if (descricaoForm.length < 2) {
      throw Exception('Descrição deve conter no mínimo 2 caracteres');
    }
    if (form.isEdit) {
      if (BackendClient.equipamentos.data.any((e) =>
          e.descricao.trim().toLowerCase() == descricaoForm.toLowerCase() &&
          e.id.toString().trim() != form.id.toString().trim())) {
        throw Exception('Já existe um equipamento com essa descrição');
      }
    } else {
      if (BackendClient.equipamentos.data.any((e) =>
          e.descricao.trim().toLowerCase() == descricaoForm.toLowerCase())) {
        throw Exception('Já existe um equipamento com essa descrição');
      }
    }
  }
}
