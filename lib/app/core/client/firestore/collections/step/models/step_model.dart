import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_shipping_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/usuario_role.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

class StepModel {
  final String id;
  final String name;
  final Color color;
  final List<UsuarioRole> moveRoles;
  final DateTime createdAt;
  final ScrollController scrollController = ScrollController();
  int index;
  List<String> fromStepsIds;
  bool isDefault = false;
  bool isShipping = false;
  StepShippingModel? shipping;
  bool isArchivedAvailable = false;
  bool isPermiteProducao = false;
  bool considerarConsumoRelatorioPedidos = true;

  static StepModel notFound = StepModel(
    createdAt: DateTime.now(),
    fromStepsIds: [],
    isDefault: false,
    moveRoles: [],
    color: Colors.transparent,
    id: 'step-not-found',
    name: 'step-not-found',
    index: 100000000,
    isShipping: false,
    shipping: null,
    isArchivedAvailable: false,
    isPermiteProducao: false,
    considerarConsumoRelatorioPedidos: false,
  );

  List<StepModel> get fromSteps => fromStepsIds
      .map<StepModel>(
        (e) => FirestoreClient.steps
            .getById(e)
            .copyWith(fromStepsIds: [], toStepsIds: []),
      )
      .toList();

  bool get isEnable => moveRoles.contains(usuario.role);

  StepModel({
    required this.id,
    required this.name,
    required this.color,
    required this.fromStepsIds,
    required this.moveRoles,
    required this.createdAt,
    required this.index,
    required this.isDefault,
    required this.isShipping,
    required this.shipping,
    required this.isArchivedAvailable,
    required this.isPermiteProducao,
    required this.considerarConsumoRelatorioPedidos,
  });

  StepModel copyWith({
    String? id,
    String? name,
    Color? color,
    List<String>? fromStepsIds,
    List<String>? toStepsIds,
    List<UsuarioRole>? moveRoles,
    DateTime? createdAt,
    int? index,
    bool? isDefault,
    bool? isShipping,
    StepShippingModel? shipping,
    bool? isArchivedAvailable,
    bool? isPermiteProducao,
    bool? considerarConsumoRelatorioPedidos,
  }) {
    return StepModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      fromStepsIds: fromStepsIds ?? this.fromStepsIds,
      moveRoles: moveRoles ?? this.moveRoles,
      createdAt: createdAt ?? this.createdAt,
      index: index ?? this.index,
      isDefault: isDefault ?? this.isDefault,
      isShipping: isShipping ?? this.isShipping,
      shipping: shipping ?? this.shipping,
      isArchivedAvailable: isArchivedAvailable ?? this.isArchivedAvailable,
      isPermiteProducao: isPermiteProducao ?? this.isPermiteProducao,
      considerarConsumoRelatorioPedidos:
          considerarConsumoRelatorioPedidos ??
          this.considerarConsumoRelatorioPedidos,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'fromStepsIds': fromStepsIds,
      'moveRoles': moveRoles.map((x) => x.index).toList(),
      'createdAt': createdAt.millisecondsSinceEpoch,
      'index': index,
      'isDefault': isDefault,
      'isShipping': isShipping,
      'shipping': shipping?.toMap(),
      'isArchivedAvailable': isArchivedAvailable,
      'isPermiteProducao': isPermiteProducao,
      'considerarConsumoRelatorioPedidos': considerarConsumoRelatorioPedidos,
    };
  }

  Map<String, dynamic> toHistoryMap() {
    return {
      'id': id,
      'name': name,
      'color': color.value,
      'isShipping': isShipping,
      'shipping': shipping?.toMap(),
    };
  }

  factory StepModel.fromMap(
    Map<String, dynamic> map, {
    bool isHistory = false,
  }) {
    if (isHistory) {
      return StepModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        index: 0,
        color: Colors.tealAccent,
        fromStepsIds: <String>[],
        moveRoles: <UsuarioRole>[],
        createdAt: DateTime.now(),
        isDefault: false,
        isShipping: map['isShipping'] ?? false,
        shipping: map['shipping'] != null
            ? StepShippingModel.fromMap(map['shipping'])
            : null,
        isArchivedAvailable: false,
        isPermiteProducao: false,
        considerarConsumoRelatorioPedidos: false,
      );
    }
    return StepModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      index: map['index'] ?? 0,
      color: Color(map['color']),
      fromStepsIds: map['fromStepsIds'] != null
          ? List<String>.from(map['fromStepsIds'])
          : <String>[],
      moveRoles: map['perfis_movimentacao'] != null
          ? ((map['perfis_movimentacao'] is String
                      ? json.decode(map['perfis_movimentacao'])
                      : map['perfis_movimentacao']) as List)
                  .map((x) {
                    if (x is int && x < UsuarioRole.values.length) {
                      return UsuarioRole.values[x];
                    }
                    return null;
                  })
                  .whereType<UsuarioRole>()
                  .toList()
          : [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      isDefault: map['isDefault'] ?? false,
      isShipping: map['isShipping'] ?? false,
      shipping: map['shipping'] != null
          ? StepShippingModel.fromMap(map['shipping'])
          : null,
      isArchivedAvailable: map['isArchivedAvailable'] ?? false,
      isPermiteProducao: map['isPermiteProducao'] ?? false,
      considerarConsumoRelatorioPedidos:
          map['considerarConsumoRelatorioPedidos'] ?? true,
    );
  }

  factory StepModel.fromSupabaseMap(Map<String, dynamic> map) {
    return StepModel(
      id: map['id'] ?? '',
      name: map['nome'] ?? '',
      index: map['index'] ?? 0,
      color: Color(map['cor'] ?? Colors.tealAccent.value),
      fromStepsIds: _parseList(map['de_etapas']),
      moveRoles: _parseRoles(map['perfis_movimentacao']),
      createdAt: map['criado_em'] != null
          ? DateTime.tryParse(map['criado_em'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isDefault: map['is_padrao'] ?? false,
      isShipping: map['is_entrega'] ?? false,
      shipping: _parseShipping(map['dados_entrega']),
      isArchivedAvailable: map['is_arquivado_disponivel'] ?? false,
      isPermiteProducao: map['is_permite_producao'] ?? false,
      considerarConsumoRelatorioPedidos:
          map['considerar_consumo_relatorio_pedidos'] ?? true,
    );
  }

  static List<String> _parseList(dynamic val) {
    if (val == null) return [];
    if (val is String) {
      try {
        return List<String>.from(json.decode(val));
      } catch (_) {
        return [];
      }
    }
    return List<String>.from(val);
  }

  static List<UsuarioRole> _parseRoles(dynamic val) {
    if (val == null) return [];
    try {
      final list = val is String ? json.decode(val) : val;
      return (list as List).map((x) {
        if (x is int && x < UsuarioRole.values.length) {
          return UsuarioRole.values[x];
        }
        return null;
      }).whereType<UsuarioRole>().toList();
    } catch (_) {
      return [];
    }
  }

  static StepShippingModel? _parseShipping(dynamic val) {
    if (val == null) return null;
    try {
      final map = val is String ? json.decode(val) : val;
      return StepShippingModel.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'nome': name,
      'index': index,
      'cor': color.value,
      'de_etapas': fromStepsIds,
      'perfis_movimentacao': moveRoles.map((e) => e.index).toList(),
      'criado_em': createdAt.toIso8601String(),
      'is_padrao': isDefault,
      'is_entrega': isShipping,
      'dados_entrega': shipping?.toMap(),
      'is_arquivado_disponivel': isArchivedAvailable,
      'is_permite_producao': isPermiteProducao,
      'considerar_consumo_relatorio_pedidos': considerarConsumoRelatorioPedidos,
    };
  }

  String toJson() => json.encode(toMap());

  factory StepModel.fromJson(String source) =>
      StepModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'StepModel(id: $id, name: $name, color: $color, fromSteps: $fromSteps, moveRoles: $moveRoles, createdAt: $createdAt, index: $index, isDefault: $isDefault, isShipping: $isShipping, shipping: $shipping, isArchivedAvailable: $isArchivedAvailable, considerarConsumoRelatorioPedidos: $considerarConsumoRelatorioPedidos  )';
  }
}
