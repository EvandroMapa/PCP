import 'dart:convert';

import 'package:aco_plus/app/core/services/hash_service.dart';

class EquipamentoModel {
  final String id;
  final String codigo;
  final String descricao;

  factory EquipamentoModel.empty() => EquipamentoModel(
        id: HashService.get,
        codigo: '',
        descricao: 'Equipamento não encontrado',
      );

  EquipamentoModel({
    required this.id,
    required this.codigo,
    required this.descricao,
  });

  String get label => codigo.isNotEmpty ? '$codigo - $descricao' : descricao;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo': codigo,
      'descricao': descricao,
    };
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'codigo': codigo,
      'descricao': descricao,
    };
  }

  factory EquipamentoModel.fromMap(Map<String, dynamic> map) {
    return EquipamentoModel(
      id: map['id'] ?? '',
      codigo: map['codigo'] ?? '',
      descricao: map['descricao'] ?? '',
    );
  }

  factory EquipamentoModel.fromSupabaseMap(Map<String, dynamic> map) =>
      EquipamentoModel.fromMap(map);

  String toJson() => json.encode(toMap());

  factory EquipamentoModel.fromJson(String source) =>
      EquipamentoModel.fromMap(json.decode(source));

  EquipamentoModel copyWith({
    String? id,
    String? codigo,
    String? descricao,
  }) {
    return EquipamentoModel(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      descricao: descricao ?? this.descricao,
    );
  }

  @override
  String toString() => label;
}
