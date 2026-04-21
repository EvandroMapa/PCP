import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class PedidoStepModel {
  final String id;
  final DateTime createdAt;
  StepModel step;
  // Guarda o ID bruto para nunca perder o vínculo mesmo quando
  // o StepModel não resolve (race condition na inicialização)
  final String stepId;

  PedidoStepModel({
    required this.id,
    required this.step,
    required this.createdAt,
    String? stepId,
  }) : stepId = stepId ?? step.id;

  factory PedidoStepModel.create(StepModel step) => PedidoStepModel(
        id: HashService.get,
        step: step,
        stepId: step.id,
        createdAt: DateTime.now(),
      );

  factory PedidoStepModel.empty() => PedidoStepModel(
        id: '',
        step: StepModel.notFound,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'step': step.id,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PedidoStepModel.fromMap(Map<String, dynamic> map) {
    final rawId = map['step'] ?? '';
    return PedidoStepModel(
      id: map['id'],
      stepId: rawId,
      step: FirestoreClient.steps.getById(rawId),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  Map<String, dynamic> toSupabaseMap(String pedidoId) {
    // Usa stepId bruto para nunca salvar 'step-not-found' no banco
    final idParaSalvar = stepId.isNotEmpty && stepId != 'step-not-found'
        ? stepId
        : step.id;
    return {
      'id': id,
      'pedido_id': pedidoId,
      'step_id': idParaSalvar,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PedidoStepModel.fromSupabaseMap(Map<String, dynamic> map) {
    final rawId = map['step_id'] ?? '';
    return PedidoStepModel(
      id: map['id'] ?? '',
      stepId: rawId,
      step: FirestoreClient.steps.getById(rawId),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory PedidoStepModel.fromJson(String source) =>
      PedidoStepModel.fromMap(json.decode(source));

  PedidoStepModel copyWith({String? id, StepModel? step, DateTime? createdAt, String? stepId}) {
    return PedidoStepModel(
      id: id ?? this.id,
      step: step ?? this.step,
      stepId: stepId ?? this.stepId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
