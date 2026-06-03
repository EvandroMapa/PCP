import 'dart:convert';

import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:flutter/material.dart';

enum PedidoBitolaStatus { separado, aguardandoProducao, produzindo, pronto }

List<PedidoBitolaStatus> pedidoProdutoStatusValues =
    PedidoBitolaStatus.values.sublist(1);

extension PedidoBitolaStatusExt on PedidoBitolaStatus {
  String get label {
    switch (this) {
      case PedidoBitolaStatus.separado:
        return 'Separado';
      case PedidoBitolaStatus.aguardandoProducao:
        return 'Aguardando Produção';
      case PedidoBitolaStatus.produzindo:
        return 'Produzindo';
      case PedidoBitolaStatus.pronto:
        return 'Pronto';
    }
  }

  Color get color {
    switch (this) {
      case PedidoBitolaStatus.separado:
        return Colors.grey;
      case PedidoBitolaStatus.aguardandoProducao:
        return Colors.red;
      case PedidoBitolaStatus.produzindo:
        return Colors.yellow;
      case PedidoBitolaStatus.pronto:
        return Colors.green;
    }
  }

  Color getColorPedidoProdutoPai(bool isExpanded) {
    switch (this) {
      case PedidoBitolaStatus.separado:
        return isExpanded ? Colors.grey : Colors.white;
      case PedidoBitolaStatus.aguardandoProducao:
        return isExpanded ? Colors.grey : Colors.white;
      case PedidoBitolaStatus.produzindo:
        return isExpanded ? Colors.grey : Colors.white;
      case PedidoBitolaStatus.pronto:
        return Colors.green;
    }
  }
}

class PedidoBitolaStatusModel {
  final String id;
  PedidoBitolaStatus status;
  final DateTime createdAt;

  factory PedidoBitolaStatusModel.empty() => PedidoBitolaStatusModel(
        createdAt: DateTime.now(),
        id: HashService.get,
        status: PedidoBitolaStatus.separado,
      );

  PedidoBitolaStatus getStatusMinified() {
    return status;
  }

  PedidoBitolaStatus getStatusView() {
    return status;
  }

  PedidoBitolaStatusModel({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  factory PedidoBitolaStatusModel.create(PedidoBitolaStatus status) =>
      PedidoBitolaStatusModel(
        id: HashService.get,
        createdAt: DateTime.now(),
        status: status,
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status.index,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PedidoBitolaStatusModel.fromMap(Map<String, dynamic> map) {
    return PedidoBitolaStatusModel(
      id: map['id'] ?? '',
      status: () {
        final val = map['status'];
        if (val is String) {
          return PedidoBitolaStatus.values.firstWhere(
            (e) => e.name == val || e.index.toString() == val,
            orElse: () => PedidoBitolaStatus.separado,
          );
        }
        return PedidoBitolaStatus.values[int.tryParse(val.toString()) ?? 0];
      }(),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (double.tryParse(map['createdAt'].toString()) ?? 0).toInt())
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory PedidoBitolaStatusModel.fromJson(String source) =>
      PedidoBitolaStatusModel.fromMap(json.decode(source));

  PedidoBitolaStatusModel copyWith({
    String? id,
    PedidoBitolaStatus? status,
    DateTime? createdAt,
  }) {
    return PedidoBitolaStatusModel(
      id: id ?? this.id,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
