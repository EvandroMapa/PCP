import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class EstoqueModel {
  final String id;
  final String produtoId;
  double quantidade;
  final double estoqueMinimo;
  final String unidade;
  final DateTime updatedAt;

  EstoqueModel({
    required this.id,
    required this.produtoId,
    required this.quantidade,
    this.estoqueMinimo = 0,
    this.unidade = 'kg',
    required this.updatedAt,
  });

  ProdutoModel get produto {
    try {
      return BackendClient.produtos.getById(produtoId);
    } catch (_) {
      return ProdutoModel.empty();
    }
  }

  factory EstoqueModel.novo(String produtoId) => EstoqueModel(
        id: HashService.get,
        produtoId: produtoId,
        quantidade: 0,
        estoqueMinimo: 0,
        unidade: 'kg',
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'produto_id': produtoId,
        'quantidade': quantidade,
        'estoque_minimo': estoqueMinimo,
        'unidade': unidade,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory EstoqueModel.fromSupabaseMap(Map<String, dynamic> map) => EstoqueModel(
        id: map['id'] ?? '',
        produtoId: map['produto_id'] ?? '',
        quantidade:
            double.tryParse((map['quantidade'] ?? 0).toString()) ?? 0.0,
        estoqueMinimo:
            double.tryParse((map['estoque_minimo'] ?? 0).toString()) ?? 0.0,
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
    String? unidade,
    DateTime? updatedAt,
  }) =>
      EstoqueModel(
        id: id ?? this.id,
        produtoId: produtoId ?? this.produtoId,
        quantidade: quantidade ?? this.quantidade,
        estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
        unidade: unidade ?? this.unidade,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
