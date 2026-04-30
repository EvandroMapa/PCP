import 'dart:convert';

/// Modelo de um Plano de Corte salvo no Supabase.
class PlanoCorteGravadoModel {
  final String id;
  final String ordemId;
  final String ordemLocalizator;
  final String bitolaDescricao;
  final String descricao;
  final String status; // 'pendente' ou 'executado'
  final bool arquivado;
  final int totalBarrasUsadas;
  final double percentualAproveitamento;
  final double totalSobra;
  final int totalElementos;
  final int totalPosicoes;
  final Map<String, dynamic> resultadoJson;
  final List<dynamic> materiaPrimaJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlanoCorteGravadoModel({
    required this.id,
    required this.ordemId,
    required this.ordemLocalizator,
    required this.bitolaDescricao,
    required this.descricao,
    this.status = 'pendente',
    this.arquivado = false,
    required this.totalBarrasUsadas,
    required this.percentualAproveitamento,
    required this.totalSobra,
    required this.totalElementos,
    required this.totalPosicoes,
    required this.resultadoJson,
    required this.materiaPrimaJson,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlanoCorteGravadoModel.fromSupabaseMap(Map<String, dynamic> map) {
    return PlanoCorteGravadoModel(
      id: map['id'] ?? '',
      ordemId: map['ordem_id'] ?? '',
      ordemLocalizator: map['ordem_localizator'] ?? '',
      bitolaDescricao: map['bitola_descricao'] ?? '',
      descricao: map['descricao'] ?? '',
      status: map['status'] ?? 'pendente',
      arquivado: map['arquivado'] == true,
      totalBarrasUsadas: map['total_barras_usadas'] ?? 0,
      percentualAproveitamento:
          (map['percentual_aproveitamento'] ?? 0).toDouble(),
      totalSobra: (map['total_sobra'] ?? 0).toDouble(),
      totalElementos: map['total_elementos'] ?? 0,
      totalPosicoes: map['total_posicoes'] ?? 0,
      resultadoJson: map['resultado_json'] is String
          ? json.decode(map['resultado_json'])
          : (map['resultado_json'] ?? {}),
      materiaPrimaJson: map['materia_prima_json'] is String
          ? json.decode(map['materia_prima_json'])
          : (map['materia_prima_json'] ?? []),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'ordem_id': ordemId,
        'ordem_localizator': ordemLocalizator,
        'bitola_descricao': bitolaDescricao,
        'descricao': descricao,
        'status': status,
        'arquivado': arquivado,
        'total_barras_usadas': totalBarrasUsadas,
        'percentual_aproveitamento': percentualAproveitamento,
        'total_sobra': totalSobra,
        'total_elementos': totalElementos,
        'total_posicoes': totalPosicoes,
        'resultado_json': resultadoJson,
        'materia_prima_json': materiaPrimaJson,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
