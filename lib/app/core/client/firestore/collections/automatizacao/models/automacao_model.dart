import 'dart:convert';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:flutter/foundation.dart';

class AutomacaoModel {
  final String id;
  final String nome;
  final String descricao;
  final int index;
  final List<StepModel> steps;

  AutomacaoModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.index,
    required this.steps,
  });

  factory AutomacaoModel.empty() => AutomacaoModel(
        id: HashService.get,
        nome: '',
        descricao: '',
        index: 0,
        steps: [],
      );

  AutomacaoModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    int? index,
    List<StepModel>? steps,
  }) {
    return AutomacaoModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      index: index ?? this.index,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'index': index,
      'steps': steps.map((x) => x.id).toList(),
    };
  }

  factory AutomacaoModel.fromMap(Map<String, dynamic> map) {
    return AutomacaoModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      descricao: map['descricao'] ?? '',
      index: map['index']?.toInt() ?? 0,
      steps: map['steps'] != null
          ? List<StepModel>.from(
              map['steps']?.map((x) => FirestoreClient.steps.getById(x)))
          : [],
    );
  }

  String toJson() => json.encode(toMap());

  factory AutomacaoModel.fromJson(String source) =>
      AutomacaoModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'AutomacaoModel(id: $id, nome: $nome, index: $index)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AutomacaoModel &&
        other.id == id &&
        other.nome == nome &&
        other.descricao == descricao &&
        other.index == index &&
        listEquals(other.steps, steps);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        nome.hashCode ^
        descricao.hashCode ^
        index.hashCode ^
        steps.hashCode;
  }
}
