import 'dart:convert';
import 'package:flutter/material.dart';

class BoxModel {
  final String id;
  final String patioId;
  final String nome;
  final int x;
  final int y;
  final int comprimento;
  final int largura;
  final int cor;
  final int maxPedidos;
  final DateTime createdAt;

  BoxModel({
    required this.id,
    required this.patioId,
    required this.nome,
    required this.x,
    required this.y,
    required this.comprimento,
    required this.largura,
    required this.cor,
    this.maxPedidos = 1,
    required this.createdAt,
  });

  Color get color => Color(cor);

  factory BoxModel.empty() => BoxModel(
        id: '',
        patioId: '',
        nome: '',
        x: 0,
        y: 0,
        comprimento: 1,
        largura: 1,
        cor: 0xFF3B82F6,
        maxPedidos: 1,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'patio_id': patioId,
        'nome': nome,
        'x': x,
        'y': y,
        'comprimento': comprimento,
        'largura': largura,
        'cor': cor.toSigned(32), // Postgres integer é signed 32-bit
        'max_pedidos': maxPedidos,
        'created_at': createdAt.toIso8601String(),
      };

  factory BoxModel.fromSupabaseMap(Map<String, dynamic> map) => BoxModel(
        id: map['id'] ?? '',
        patioId: map['patio_id'] ?? '',
        nome: map['nome'] ?? '',
        x: map['x'] ?? 0,
        y: map['y'] ?? 0,
        comprimento: map['comprimento'] ?? 1,
        largura: map['largura'] ?? 1,
        cor: ((map['cor'] ?? 0xFF3B82F6) as int).toUnsigned(32), // reverter signed→unsigned
        maxPedidos: map['max_pedidos'] ?? 1,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'])
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'patioId': patioId,
        'nome': nome,
        'x': x,
        'y': y,
        'comprimento': comprimento,
        'largura': largura,
        'cor': cor,
        'maxPedidos': maxPedidos,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory BoxModel.fromMap(Map<String, dynamic> map) => BoxModel(
        id: map['id'] ?? '',
        patioId: map['patioId'] ?? '',
        nome: map['nome'] ?? '',
        x: map['x'] ?? 0,
        y: map['y'] ?? 0,
        comprimento: map['comprimento'] ?? 1,
        largura: map['largura'] ?? 1,
        cor: map['cor'] ?? 0xFF3B82F6,
        maxPedidos: map['maxPedidos'] ?? 1,
        createdAt: map['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
            : DateTime.now(),
      );

  String toJson() => json.encode(toMap());
  factory BoxModel.fromJson(String source) =>
      BoxModel.fromMap(json.decode(source));

  BoxModel copyWith({
    String? id,
    String? patioId,
    String? nome,
    int? x,
    int? y,
    int? comprimento,
    int? largura,
    int? cor,
    int? maxPedidos,
    DateTime? createdAt,
  }) =>
      BoxModel(
        id: id ?? this.id,
        patioId: patioId ?? this.patioId,
        nome: nome ?? this.nome,
        x: x ?? this.x,
        y: y ?? this.y,
        comprimento: comprimento ?? this.comprimento,
        largura: largura ?? this.largura,
        cor: cor ?? this.cor,
        maxPedidos: maxPedidos ?? this.maxPedidos,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  String toString() => nome;
}
