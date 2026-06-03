import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class EstoqueModel {
  final String id;
  final String produtoId;
  double quantidade;
  final double estoqueMinimo;
  final double estoqueIdeal;
  final String unidade;
  final DateTime updatedAt;

  EstoqueModel({
    required this.id,
    required this.produtoId,
    required this.quantidade,
    this.estoqueMinimo = 0,
    this.estoqueIdeal = 0,
    this.unidade = 'kg',
    required this.updatedAt,
  });

  BitolaModel get produto {
    try {
      return BackendClient.bitolas.getById(produtoId);
    } catch (_) {
      return BitolaModel.empty();
    }
  }

  factory EstoqueModel.novo(String produtoId) => EstoqueModel(
        id: HashService.get,
        produtoId: produtoId,
        quantidade: 0,
        estoqueMinimo: 0,
        estoqueIdeal: 0,
        unidade: 'kg',
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'bitola_id': produtoId,
        'quantidade': quantidade,
        'estoque_minimo': estoqueMinimo,
        'estoque_ideal': estoqueIdeal,
        'unidade': unidade,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory EstoqueModel.fromSupabaseMap(Map<String, dynamic> map) => EstoqueModel(
        id: map['id'] ?? '',
        produtoId: map['bitola_id'] ?? '',
        quantidade:
            double.tryParse((map['quantidade'] ?? 0).toString()) ?? 0.0,
        estoqueMinimo:
            double.tryParse((map['estoque_minimo'] ?? 0).toString()) ?? 0.0,
        estoqueIdeal:
            double.tryParse((map['estoque_ideal'] ?? 0).toString()) ?? 0.0,
        unidade: map['unidade'] ?? 'kg',
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'])
            : DateTime.now(),
      );

  EstoqueModel copyWith({
    String? id,
    String? produtoId,
    double? quantidade,
    double? estoqueMinimo,
    double? estoqueIdeal,
    String? unidade,
    DateTime? updatedAt,
  }) =>
      EstoqueModel(
        id: id ?? this.id,
        produtoId: produtoId ?? this.produtoId,
        quantidade: quantidade ?? this.quantidade,
        estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
        estoqueIdeal: estoqueIdeal ?? this.estoqueIdeal,
        unidade: unidade ?? this.unidade,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
