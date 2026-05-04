import 'dart:convert';

class PatioModel {
  final String id;
  final String nome;
  final int comprimento; // metros (eixo X)
  final int largura; // metros (eixo Y)
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  PatioModel({
    required this.id,
    required this.nome,
    required this.comprimento,
    required this.largura,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory PatioModel.empty() => PatioModel(
        id: '',
        nome: '',
        comprimento: 0,
        largura: 0,
        latitude: null,
        longitude: null,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'nome': nome,
      'comprimento': comprimento,
      'largura': largura,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PatioModel.fromSupabaseMap(Map<String, dynamic> map) {
    return PatioModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      comprimento: map['comprimento'] ?? 0,
      largura: map['largura'] ?? 0,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'comprimento': comprimento,
      'largura': largura,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PatioModel.fromMap(Map<String, dynamic> map) {
    return PatioModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      comprimento: map['comprimento'] ?? 0,
      largura: map['largura'] ?? 0,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory PatioModel.fromJson(String source) =>
      PatioModel.fromMap(json.decode(source));

  PatioModel copyWith({
    String? id,
    String? nome,
    int? comprimento,
    int? largura,
    double? Function()? latitude,
    double? Function()? longitude,
    DateTime? createdAt,
  }) {
    return PatioModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      comprimento: comprimento ?? this.comprimento,
      largura: largura ?? this.largura,
      latitude: latitude != null ? latitude() : this.latitude,
      longitude: longitude != null ? longitude() : this.longitude,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => nome;
}
