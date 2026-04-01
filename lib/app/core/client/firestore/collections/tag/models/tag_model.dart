import 'dart:convert';

import 'package:flutter/material.dart';

class TagModel {
  final String id;
  final String nome;
  final String descricao;
  final Color color;
  final DateTime createdAt;
  TagModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.color,
    required this.createdAt,
  });

  factory TagModel.empty() => TagModel(
    id: '',
    nome: '',
    descricao: '',
    color: Colors.transparent,
    createdAt: DateTime.now(),
  );

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'color': color.value,
      'created_at': createdAt.toIso8601String(),
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'color': color.value,
      'createdAt': createdAt.millisecondsSinceEpoch,
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
    );
  }

  String toJson() => json.encode(toMap());

  factory TagModel.fromJson(String source) =>
      TagModel.fromMap(json.decode(source));
}
