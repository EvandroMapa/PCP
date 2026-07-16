import 'dart:convert';

import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:flutter/material.dart';

enum PedidoBitolaStatus { separado, aguardandoProducao, produzindo, aguardaSegundaEtapa, pronto }

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
      case PedidoBitolaStatus.aguardaSegundaEtapa:
        return 'Aguardando 2ª Etapa';
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
      case PedidoBitolaStatus.aguardaSegundaEtapa:
        return Colors.orange;
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
      case PedidoBitolaStatus.aguardaSegundaEtapa:
        return isExpanded ? Colors.orange : Colors.white;
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
      'status': status.name,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory PedidoBitolaStatusModel.fromMap(Map<String, dynamic> map) {
    return PedidoBitolaStatusModel(
      id: map['id'] ?? '',
      status: () {
        final val = map['status'];
        if (val is String) {
          // Tenta por nome primeiro (dados novos)
          final byName = PedidoBitolaStatus.values
              .cast<PedidoBitolaStatus?>()
              .firstWhere((e) => e!.name == val, orElse: () => null);
          if (byName != null) return byName;
          // Fallback: string numérica antiga ("0".."3")
          final idx = int.tryParse(val);
          if (idx != null) return _fromLegacyIndex(idx);
          return PedidoBitolaStatus.separado;
        }
        // Valor numérico: mapeamento legado explícito
        return _fromLegacyIndex(int.tryParse(val.toString()) ?? 0);
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

  /// Mapeia índice do enum ANTIGO (sem aguardaSegundaEtapa) para o valor correto.
  /// Enum antigo: 0=separado, 1=aguardandoProducao, 2=produzindo, 3=pronto
  /// Enum novo:   0=separado, 1=aguardandoProducao, 2=produzindo, 3=aguardaSegundaEtapa, 4=pronto
  static PedidoBitolaStatus _fromLegacyIndex(int idx) {
    switch (idx) {
      case 0:
        return PedidoBitolaStatus.separado;
      case 1:
        return PedidoBitolaStatus.aguardandoProducao;
      case 2:
        return PedidoBitolaStatus.produzindo;
      case 3:
        return PedidoBitolaStatus.pronto; // era pronto no enum antigo
      default:
        return PedidoBitolaStatus.separado;
    }
  }
}
