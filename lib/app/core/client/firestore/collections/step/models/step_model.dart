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
      name: map['nome'] ?? map['name'] ?? map['nome_etapa'] ?? '',
      index: map['index'] ?? map['ordem'] ?? 0,
      color: Color(map['cor'] ?? map['color'] ?? map['cor_hex'] ?? Colors.tealAccent.value),
      fromStepsIds: _parseList(map['de_etapas'] ?? map['fromStepsIds'] ?? map['from_steps_ids'] ?? map['origem'] ?? map['fontes']),
      moveRoles: _parseRoles(map['perfis_movimentacao'] ?? map['moveRoles'] ?? map['move_roles'] ?? map['perfis']),
      createdAt: map['criado_em'] != null || map['created_at'] != null
          ? DateTime.tryParse((map['criado_em'] ?? map['created_at']).toString()) ?? DateTime.now()
          : DateTime.now(),
      isDefault: map['is_padrao'] ?? map['isDefault'] ?? map['is_default'] ?? map['padrao'] ?? false,
      isShipping: map['is_entrega'] ?? map['isShipping'] ?? map['is_shipping'] ?? map['entrega'] ?? map['acompanhamento'] ?? false,
      shipping: _parseShipping(map['dados_entrega'] ?? map['shipping'] ?? map['entrega_dados']),
      isArchivedAvailable: map['is_arquivado_disponivel'] ?? map['isArchivedAvailable'] ?? map['is_archived_available'] ?? map['arquivamento'] ?? false,
      isPermiteProducao: map['is_permite_producao'] ?? map['isPermiteProducao'] ?? map['permite_producao'] ?? map['producao'] ?? false,
      considerarConsumoRelatorioPedidos: map['considerar_consumo_relatorio_pedidos'] ??
          map['considerarConsumoRelatorioPedidos'] ??
          map['relatorio_pedidos'] ??
          map['consumo_relatorio'] ??
          map['relatorio'] ??
          true,
    );
  }

  static List<String> _parseList(dynamic val) {
    if (val == null) return [];
    if (val is String) {
       try {
         return List<String>.from(json.decode(val));
       } catch(_) {
         return [];
       }
    }
    return List<String>.from(val);
  }

  static List<UsuarioRole> _parseRoles(dynamic val) {
    if (val == null) return [];
    final list = val is String ? json.decode(val) : val;
    return (list as List).map((x) {
      if (x is int && x < UsuarioRole.values.length) {
        return UsuarioRole.values[x];
      }
      return null;
    }).whereType<UsuarioRole>().toList();
  }

  static StepShippingModel? _parseShipping(dynamic val) {
    if (val == null) return null;
    final map = val is String ? json.decode(val) : val;
    return StepShippingModel.fromMap(map);
  }

  Map<String, dynamic> toSupabaseMap() {
    final roles = moveRoles.map((e) => e.index).toList();
    final ship = shipping?.toMap();
    final map = {
      'id': id,
      'nome': name,
      'name': name,
      'index': index,
      'cor': color.value,
      'color': color.value,
      'de_etapas': fromStepsIds,
      'fromStepsIds': fromStepsIds,
      'from_steps_ids': fromStepsIds,
      'origem': fromStepsIds,
      'perfis_movimentacao': roles,
      'moveRoles': roles,
      'move_roles': roles,
      'perfis': roles,
      'criado_em': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'is_padrao': isDefault,
      'isDefault': isDefault,
      'is_default': isDefault,
      'padrao': isDefault,
      'is_entrega': isShipping,
      'isShipping': isShipping,
      'is_shipping': isShipping,
      'entrega': isShipping,
      'acompanhamento': isShipping,
      'dados_entrega': ship,
      'shipping': ship,
      'is_arquivado_disponivel': isArchivedAvailable,
      'isArchivedAvailable': isArchivedAvailable,
      'is_archived_available': isArchivedAvailable,
      'arquivamento': isArchivedAvailable,
      'is_permite_producao': isPermiteProducao,
      'isPermiteProducao': isPermiteProducao,
      'permite_producao': isPermiteProducao,
      'producao': isPermiteProducao,
      'considerar_consumo_relatorio_pedidos': considerarConsumoRelatorioPedidos,
      'considerarConsumoRelatorioPedidos': considerarConsumoRelatorioPedidos,
      'relatorio_pedidos': considerarConsumoRelatorioPedidos,
      'consumo_relatorio': considerarConsumoRelatorioPedidos,
      'relatorio': considerarConsumoRelatorioPedidos,
    };
    print('DEBUG: StepModel.toSupabaseMap generated: $map');
    return map;
  }

  String toJson() => json.encode(toMap());

  factory StepModel.fromJson(String source) =>
      StepModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'StepModel(id: $id, name: $name, color: $color, fromSteps: $fromSteps, moveRoles: $moveRoles, createdAt: $createdAt, index: $index, isDefault: $isDefault, isShipping: $isShipping, shipping: $shipping, isArchivedAvailable: $isArchivedAvailable, considerarConsumoRelatorioPedidos: $considerarConsumoRelatorioPedidos  )';
  }
}
