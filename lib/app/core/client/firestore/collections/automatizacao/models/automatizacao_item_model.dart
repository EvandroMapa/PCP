import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/enums/automatizacao_enum.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:flutter/foundation.dart';

/// Uma regra de automação. Guarda só os ids das etapas e procura a etapa
/// na hora de usar: assim não importa se a regra foi lida antes das etapas
/// carregarem (app abrindo, aparelho voltando da suspensão, conexão
/// voltando). Antes a etapa era resolvida na leitura e, nesse caso, virava
/// "step-not-found" e a automação movia o pedido para uma etapa inexistente.
class AutomatizacaoItemModel {
  final AutomatizacaoItemType type;
  String? _stepId;
  List<String>? _stepIds;

  AutomatizacaoItemModel({
    required this.type,
    required StepModel? step,
    List<StepModel>? steps,
  }) {
    this.step = step;
    this.steps = steps;
  }

  AutomatizacaoItemModel._ids({
    required this.type,
    String? stepId,
    List<String>? stepIds,
  })  : _stepId = _valido(stepId) ? stepId : null,
        _stepIds = stepIds?.where(_valido).toList();

  static bool _valido(String? id) =>
      id != null && id.isNotEmpty && id != StepModel.notFound.id;

  /// Etapa da regra, ou null se não configurada / ainda não encontrada
  static StepModel? _resolver(String? id) {
    if (!_valido(id)) return null;
    final step = FirestoreClient.steps.getById(id!);
    return step.id == StepModel.notFound.id ? null : step;
  }

  StepModel? get step => _resolver(_stepId);
  set step(StepModel? value) =>
      _stepId = _valido(value?.id) ? value!.id : null;

  List<StepModel>? get steps => _stepIds
      ?.map(_resolver)
      .whereType<StepModel>()
      .toList();
  set steps(List<StepModel>? value) =>
      _stepIds = value?.map((e) => e.id).where(_valido).toList();

  AutomatizacaoItemModel copyWith({
    AutomatizacaoItemType? type,
    DateTime? createdAt,
    StepModel? step,
    List<StepModel>? steps,
  }) {
    return AutomatizacaoItemModel._ids(
      type: type ?? this.type,
      stepId: step?.id ?? _stepId,
      stepIds: steps?.map((e) => e.id).toList() ?? _stepIds,
    );
  }

  /// Grava os ids como estão (mesmo os de etapas ainda não carregadas),
  /// nunca "step-not-found"
  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      if (_stepId != null) 'stepId': _stepId,
      if (_stepIds != null) 'steps': _stepIds,
    };
  }

  factory AutomatizacaoItemModel.fromMap(Map<String, dynamic> map) {
    // Retrocompatibilidade: se stepId estiver ausente, tenta pegar do objeto aninhado 'step'
    String? parsedStepId = map['stepId'];
    if (parsedStepId == null && map['step'] != null) {
      if (map['step'] is Map) {
        parsedStepId = map['step']['id'];
      } else if (map['step'] is String) {
        parsedStepId = map['step'];
      }
    }

    return AutomatizacaoItemModel._ids(
      type: AutomatizacaoItemType.values[map['type']],
      stepId: parsedStepId,
      stepIds: (map['steps'] as List?)
          ?.map((e) => e is Map ? e['id'].toString() : e.toString())
          .toList(),
    );
  }

  String toJson() => json.encode(toMap());

  factory AutomatizacaoItemModel.fromJson(String source) =>
      AutomatizacaoItemModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'AutomatizacaoItemModel(type: $type, stepId: $_stepId, steps: $_stepIds)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AutomatizacaoItemModel &&
        other.type == type &&
        other._stepId == _stepId &&
        listEquals(other._stepIds, _stepIds);
  }

  @override
  int get hashCode {
    return type.hashCode ^ _stepId.hashCode ^ _stepIds.hashCode;
  }
}
