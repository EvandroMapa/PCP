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
      color: Color(map['color']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory TagModel.fromJson(String source) =>
      TagModel.fromMap(json.decode(source));
}
