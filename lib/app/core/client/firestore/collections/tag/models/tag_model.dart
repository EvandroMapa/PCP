import 'dart:convert';

import 'package:flutter/material.dart';

class TagModel {
  final String id;
  final String nome;
  final String descricao;
  final Color color;
  final DateTime createdAt;
  final bool isDefaultCD;
  final bool isDefaultCDA;

  TagModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.color,
    required this.createdAt,
    this.isDefaultCD = false,
    this.isDefaultCDA = false,
  });

  factory TagModel.empty() => TagModel(
    id: '',
    nome: '',
    descricao: '',
    color: Colors.transparent,
    createdAt: DateTime.now(),
    isDefaultCD: false,
    isDefaultCDA: false,
  );

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'color': color.value,
      'created_at': createdAt.toIso8601String(),
      'is_default_cd': isDefaultCD,
      'is_default_cda': isDefaultCDA,
    };
  }

  factory TagModel.fromSupabaseMap(Map<String, dynamic> map) {
    return TagModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      descricao: map['descricao'] ?? '',
      color: Color(int.tryParse(map['color'].toString()) ?? 0),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      isDefaultCD: map['is_default_cd'] ?? false,
      isDefaultCDA: map['is_default_cda'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'color': color.value,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'isDefaultCD': isDefaultCD,
      'isDefaultCDA': isDefaultCDA,
    };
  }

  factory TagModel.fromMap(Map<String, dynamic> map) {
    return TagModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      descricao: map['descricao'] ?? '',
      color: Color(map['color'] ?? 0),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
      isDefaultCD: map['isDefaultCD'] ?? false,
      isDefaultCDA: map['isDefaultCDA'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory TagModel.fromJson(String source) =>
      TagModel.fromMap(json.decode(source));

  TagModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    Color? color,
    DateTime? createdAt,
    bool? isDefaultCD,
    bool? isDefaultCDA,
  }) {
    return TagModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      isDefaultCD: isDefaultCD ?? this.isDefaultCD,
      isDefaultCDA: isDefaultCDA ?? this.isDefaultCDA,
    );
  }
}
