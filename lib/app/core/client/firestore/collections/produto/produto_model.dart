import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class ProdutoModel {
  final String id;
  final String nome;
  final String descricao;
  final double massaFinal;
  final String codigoFinanceiro;

  factory ProdutoModel.empty() => ProdutoModel(
    id: HashService.get,
    nome: 'Produto não encontrado',
    descricao: 'Este produto não foi encontrado no sistema',
    massaFinal: 0.0,
    codigoFinanceiro: '',
  );

  String get descricaoReplaced =>
      descricao.replaceAll('mm', '').replaceAll('.0', '');

  double get number =>
      double.tryParse(descricao.substring(0, descricao.length - 2)) ?? 0.0;

  ProdutoModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.massaFinal,
    this.codigoFinanceiro = '',
  });

  String get label => '$nome - $descricao - $massaFinal';

  String get labelMinified => '$nome - $descricao';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'massaFinal': massaFinal,
      'codigoFinanceiro': codigoFinanceiro,
    };
  }

  factory ProdutoModel.fromSupabaseMap(Map<String, dynamic> map) {
    return ProdutoModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      descricao: map['descricao'] ?? '',
      massaFinal: double.tryParse(map['massa_final'].toString()) ?? 0.0,
      codigoFinanceiro: map['codigo_financeiro']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'massa_final': massaFinal,
      'codigo_financeiro': codigoFinanceiro,
    };
  }

  factory ProdutoModel.fromMap(Map<String, dynamic> map) {
    return ProdutoModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      descricao: map['descricao'] ?? '',
      massaFinal: double.tryParse(map['massaFinal']?.toString() ?? '0') ?? 0.0,
      codigoFinanceiro: map['codigoFinanceiro']?.toString() ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory ProdutoModel.fromJson(String source) =>
      ProdutoModel.fromMap(json.decode(source));

  ProdutoModel copyWith({
    String? id,
    String? nome,
    String? descricao,
    FabricanteModel? fabricante,
    double? massaFinal,
    String? codigoFinanceiro,
  }) {
    return ProdutoModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      massaFinal: massaFinal ?? this.massaFinal,
      codigoFinanceiro: codigoFinanceiro ?? this.codigoFinanceiro,
    );
  }
}
