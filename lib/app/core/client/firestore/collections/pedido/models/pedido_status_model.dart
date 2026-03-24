import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_status.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';

class PedidoStatusModel {
  final String id;
  PedidoStatus status;
  final DateTime createdAt;
  PedidoStatusModel({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  factory PedidoStatusModel.create(PedidoStatus status) => PedidoStatusModel(
    id: HashService.get,
    createdAt: DateTime.now(),
    status: status,
  );

  factory PedidoStatusModel.empty() => PedidoStatusModel(
    id: '',
    createdAt: DateTime.now(),
    status: PedidoStatus.aguardandoProducaoCD,
  );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PedidoStatusModel.fromMap(Map<String, dynamic> map) {
    return PedidoStatusModel(
      id: map['id'],
      status: PedidoStatus.values[map['status']],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  Map<String, dynamic> toSupabaseMap(String pedidoId) {
    return {
      'id': id,
      'pedido_id': pedidoId,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PedidoStatusModel.fromSupabaseMap(Map<String, dynamic> map) {
    return PedidoStatusModel(
      id: map['id'] ?? '',
      status: PedidoStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PedidoStatus.aguardandoProducaoCD,
      ),
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory PedidoStatusModel.fromJson(String source) =>
      PedidoStatusModel.fromMap(json.decode(source));

  PedidoStatusModel copyWith({
    String? id,
    PedidoStatus? status,
    DateTime? createdAt,
  }) {
    return PedidoStatusModel(
      id: id ?? this.id,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
