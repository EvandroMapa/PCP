import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

enum PedidoCompraStatus {
  pendente,
  confirmado,
  convertido,
  descartado;

  String get label => switch (this) {
        PedidoCompraStatus.pendente => 'Pendente',
        PedidoCompraStatus.confirmado => 'Confirmado',
        PedidoCompraStatus.convertido => 'Efetivado',
        PedidoCompraStatus.descartado => 'Descartado',
      };
}

class PedidoCompraModel {
  final String id;
  final String grupoId;
  final String produtoId;
  final String fabricanteId;
  final double quantidade;
  final double? quantidadeRecebida;
  PedidoCompraStatus status;
  final DateTime? dataPrevista;    // data estimada de chegada (status confirmado)
  final String? observacao;
  final String? usuarioNome;
  final DateTime createdAt;
  final DateTime updatedAt;

  PedidoCompraModel({
    required this.id,
    required this.grupoId,
    required this.produtoId,
    required this.fabricanteId,
    required this.quantidade,
    this.quantidadeRecebida,
    required this.status,
    this.dataPrevista,
    this.observacao,
    this.usuarioNome,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPendente => status == PedidoCompraStatus.pendente;
  bool get isConfirmado => status == PedidoCompraStatus.confirmado;
  bool get isConvertido => status == PedidoCompraStatus.convertido;
  bool get isDescartado => status == PedidoCompraStatus.descartado;

  /// Pendente ou confirmado — ainda não chegou ao estoque
  bool get isAtivo => isPendente || isConfirmado;

  BitolaModel get produto {
    try {
      return BackendClient.bitolas.getById(produtoId);
    } catch (_) {
      return BitolaModel.empty();
    }
  }

  FabricanteModel get fabricante {
    try {
      return BackendClient.fabricantes.getById(fabricanteId);
    } catch (_) {
      return FabricanteModel.empty();
    }
  }

  factory PedidoCompraModel.novo({
    required String grupoId,
    required String produtoId,
    required String fabricanteId,
    required double quantidade,
    String? observacao,
    String? usuarioNome,
  }) =>
      PedidoCompraModel(
        id: HashService.get,
        grupoId: grupoId,
        produtoId: produtoId,
        fabricanteId: fabricanteId,
        quantidade: quantidade,
        status: PedidoCompraStatus.pendente,
        observacao: observacao,
        usuarioNome: usuarioNome,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'grupo_id': grupoId,
        'bitola_id': produtoId,
        'fabricante_id': fabricanteId,
        'quantidade': quantidade,
        'quantidade_recebida': quantidadeRecebida,
        'status': status.name,
        'data_prevista': dataPrevista?.toIso8601String(),
        'observacao': observacao,
        'usuario_nome': usuarioNome,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PedidoCompraModel.fromSupabaseMap(Map<String, dynamic> map) =>
      PedidoCompraModel(
        id: map['id'] ?? '',
        grupoId: map['grupo_id'] ?? map['id'] ?? '',
        produtoId: map['bitola_id'] ?? '',
        fabricanteId: map['fabricante_id'] ?? '',
        quantidade:
            double.tryParse((map['quantidade'] ?? 0).toString()) ?? 0.0,
        quantidadeRecebida: map['quantidade_recebida'] != null
            ? double.tryParse(map['quantidade_recebida'].toString())
            : null,
        status: PedidoCompraStatus.values.firstWhere(
          (e) => e.name == (map['status'] ?? 'pendente'),
          orElse: () => PedidoCompraStatus.pendente,
        ),
        dataPrevista: map['data_prevista'] != null
            ? DateTime.tryParse(map['data_prevista'])
            : null,
        observacao: map['observacao'],
        usuarioNome: map['usuario_nome'],
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'])
            : DateTime.now(),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'])
            : DateTime.now(),
      );

  PedidoCompraModel copyWith({
    String? id,
    String? grupoId,
    String? produtoId,
    String? fabricanteId,
    double? quantidade,
    double? quantidadeRecebida,
    PedidoCompraStatus? status,
    DateTime? dataPrevista,
    bool clearDataPrevista = false,
    String? observacao,
    String? usuarioNome,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      PedidoCompraModel(
        id: id ?? this.id,
        grupoId: grupoId ?? this.grupoId,
        produtoId: produtoId ?? this.produtoId,
        fabricanteId: fabricanteId ?? this.fabricanteId,
        quantidade: quantidade ?? this.quantidade,
        quantidadeRecebida: quantidadeRecebida ?? this.quantidadeRecebida,
        status: status ?? this.status,
        dataPrevista:
            clearDataPrevista ? null : (dataPrevista ?? this.dataPrevista),
        observacao: observacao ?? this.observacao,
        usuarioNome: usuarioNome ?? this.usuarioNome,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
