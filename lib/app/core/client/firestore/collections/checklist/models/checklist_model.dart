import 'dart:convert';

import 'package:aco_plus/app/core/components/checklist/check_item_model.dart';
import 'package:flutter/foundation.dart';

class ChecklistModel {
  final String id;
  final String nome;
  final List<CheckItemModel> checklist;
  final DateTime createdAt;
  ChecklistModel({
    required this.id,
    required this.nome,
    required this.checklist,
    required this.createdAt,
  });
  
  factory ChecklistModel.empty() => ChecklistModel(
    id: '',
    nome: '',
    checklist: [],
    createdAt: DateTime.now(),
  );

  ChecklistModel copyWith({
    String? id,
    String? nome,
    List<CheckItemModel>? checklist,
    DateTime? createdAt,
  }) {
    return ChecklistModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      checklist: checklist ?? this.checklist,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'nome': nome,
      'checklist': checklist.map((x) => x.toMap()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ChecklistModel.fromSupabaseMap(Map<String, dynamic> map) {
    return ChecklistModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      checklist: map['checklist'] != null
          ? List<CheckItemModel>.from((map['checklist'] is String
                  ? json.decode(map['checklist'])
                  : map['checklist'])
              .map((x) => CheckItemModel.fromMap(x)))
          : [],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'checklist': checklist.map((x) => x.toMap()).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ChecklistModel.fromMap(Map<String, dynamic> map) {
    return ChecklistModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      checklist: map['checklist'] != null
          ? List<CheckItemModel>.from(
              map['checklist']?.map((x) => CheckItemModel.fromMap(x)),
            )
          : [],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ChecklistModel.fromJson(String source) =>
      ChecklistModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'ChecklistModel(id: $id, nome: $nome, checklist: $checklist, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChecklistModel &&
        other.id == id &&
        other.nome == nome &&
        listEquals(other.checklist, checklist) &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        nome.hashCode ^
        checklist.hashCode ^
        createdAt.hashCode;
  }
}
