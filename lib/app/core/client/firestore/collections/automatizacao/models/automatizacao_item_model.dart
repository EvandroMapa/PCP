import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/enums/automatizacao_enum.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:flutter/foundation.dart';

class AutomatizacaoItemModel {
  final AutomatizacaoItemType type;
  StepModel? step;
  List<StepModel>? steps;
  AutomatizacaoItemModel({required this.type, required this.step, this.steps});

  AutomatizacaoItemModel copyWith({
    AutomatizacaoItemType? type,
    DateTime? createdAt,
    StepModel? step,
    List<StepModel>? steps,
  }) {
    return AutomatizacaoItemModel(
      type: type ?? this.type,
      step: step ?? this.step,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      if(step != null) 'stepId': step!.id,
      if (steps != null) 'steps': steps!.map((e) => e.id).toList(),
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

    return AutomatizacaoItemModel(
      type: AutomatizacaoItemType.values[map['type']],
      step: parsedStepId != null ? FirestoreClient.steps.getById(parsedStepId) : null,
      steps: map['steps']?.map<StepModel>((e) {
        if (e is Map) return FirestoreClient.steps.getById(e['id']);
        return FirestoreClient.steps.getById(e.toString());
      }).toList(),
    );
  }

  String toJson() => json.encode(toMap());

  factory AutomatizacaoItemModel.fromJson(String source) =>
      AutomatizacaoItemModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'AutomatizacaoItemModel(type: $type, step: $step, steps: $steps)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AutomatizacaoItemModel &&
        other.type == type &&
        other.step == step &&
        listEquals(other.steps, steps);
  }

  @override
  int get hashCode {
    return type.hashCode ^ step.hashCode ^ steps.hashCode;
  }
}
