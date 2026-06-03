import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:flutter/material.dart';

enum EstoqueTipoMovimentacao {
  implantacao,
  compra,
  baixaProducao,
  estorno,
}

extension EstoqueTipoMovimentacaoExt on EstoqueTipoMovimentacao {
  String get label {
    switch (this) {
      case EstoqueTipoMovimentacao.implantacao:
        return 'Implantação';
      case EstoqueTipoMovimentacao.compra:
        return 'Compra';
      case EstoqueTipoMovimentacao.baixaProducao:
        return 'Baixa (Produção)';
      case EstoqueTipoMovimentacao.estorno:
        return 'Estorno';
    }
  }

  String get value {
    switch (this) {
      case EstoqueTipoMovimentacao.implantacao:
        return 'implantacao';
      case EstoqueTipoMovimentacao.compra:
        return 'compra';
      case EstoqueTipoMovimentacao.baixaProducao:
        return 'baixa_producao';
      case EstoqueTipoMovimentacao.estorno:
        return 'estorno';
    }
  }

  Color get cor {
    switch (this) {
      case EstoqueTipoMovimentacao.implantacao:
        return Colors.blue;
      case EstoqueTipoMovimentacao.compra:
        return Colors.green;
      case EstoqueTipoMovimentacao.baixaProducao:
        return Colors.orange;
      case EstoqueTipoMovimentacao.estorno:
        return Colors.purple;
    }
  }

  IconData get icone {
    switch (this) {
      case EstoqueTipoMovimentacao.implantacao:
        return Icons.edit_outlined;
      case EstoqueTipoMovimentacao.compra:
        return Icons.add_shopping_cart_outlined;
      case EstoqueTipoMovimentacao.baixaProducao:
        return Icons.remove_circle_outline;
      case EstoqueTipoMovimentacao.estorno:
        return Icons.undo_rounded;
    }
  }

  bool get isEntrada => this == EstoqueTipoMovimentacao.compra ||
      this == EstoqueTipoMovimentacao.implantacao ||
      this == EstoqueTipoMovimentacao.estorno;

  static EstoqueTipoMovimentacao fromValue(String value) {
    switch (value) {
      case 'implantacao':
        return EstoqueTipoMovimentacao.implantacao;
      case 'compra':
        return EstoqueTipoMovimentacao.compra;
      case 'baixa_producao':
        return EstoqueTipoMovimentacao.baixaProducao;
      case 'estorno':
        return EstoqueTipoMovimentacao.estorno;
      default:
        return EstoqueTipoMovimentacao.implantacao;
    }
  }
}

class EstoqueMovimentacaoModel {
  final String id;
  final String produtoId;
  final EstoqueTipoMovimentacao tipo;
  final double quantidade;
  final String? observacao;
  final String? ordemId;
  final DateTime dataHora;
  final String? usuarioNome;
  final DateTime createdAt;

  EstoqueMovimentacaoModel({
    required this.id,
    required this.produtoId,
    required this.tipo,
    required this.quantidade,
    this.observacao,
    this.ordemId,
    required this.dataHora,
    this.usuarioNome,
    required this.createdAt,
  });

  BitolaModel get produto {
    try {
      return BackendClient.bitolas.getById(produtoId);
    } catch (_) {
      return BitolaModel.empty();
    }
  }

  factory EstoqueMovimentacaoModel.novo({
    required String produtoId,
    required EstoqueTipoMovimentacao tipo,
    required double quantidade,
    String? observacao,
    String? ordemId,
    String? usuarioNome,
  }) =>
      EstoqueMovimentacaoModel(
        id: HashService.get,
        produtoId: produtoId,
        tipo: tipo,
        quantidade: quantidade,
        observacao: observacao,
        ordemId: ordemId,
        dataHora: DateTime.now(),
        usuarioNome: usuarioNome,
        createdAt: DateTime.now(),
      );

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'bitola_id': produtoId,
        'tipo': tipo.value,
        'quantidade': quantidade,
        'observacao': observacao,
        'ordem_id': ordemId,
        'data_hora': dataHora.toIso8601String(),
        'usuario_nome': usuarioNome,
        'created_at': createdAt.toIso8601String(),
      };

  factory EstoqueMovimentacaoModel.fromSupabaseMap(
          Map<String, dynamic> map) =>
      EstoqueMovimentacaoModel(
        id: map['id'] ?? '',
        produtoId: map['bitola_id'] ?? '',
        tipo: EstoqueTipoMovimentacaoExt.fromValue(map['tipo'] ?? ''),
        quantidade:
            double.tryParse((map['quantidade'] ?? 0).toString()) ?? 0.0,
        observacao: map['observacao'],
        ordemId: map['ordem_id'],
        dataHora: map['data_hora'] != null
            ? DateTime.parse(map['data_hora'])
            : DateTime.now(),
        usuarioNome: map['usuario_nome'],
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'])
            : DateTime.now(),
      );
}
