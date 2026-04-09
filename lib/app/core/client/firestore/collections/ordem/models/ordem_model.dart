import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/ordem_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_durations_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:flutter/material.dart';

class OrdemModel {
  final String id;
  final ProdutoModel produto;
  final DateTime createdAt;
  DateTime updatedAt;
  MateriaPrimaModel? materiaPrima;
  DateTime? endAt;
  List<Map<String, String>> idPedidosProdutosRefs = [];
  List<PedidoProdutoModel>? _produtosIniciais;

  List<PedidoProdutoModel> get produtos {
    if (idPedidosProdutosRefs.isNotEmpty) {
      final List<PedidoProdutoModel> result = [];
      for (var x in idPedidosProdutosRefs) {
        try {
          final pedidoId = x['pedidoId'] ?? x['pedido_id'] ?? '';
          final produtoId = x['produtoId'] ?? x['produto_id'] ?? '';
          if (pedidoId.isEmpty || produtoId.isEmpty) continue;

          final produto = BackendClient.pedidos.getProdutoByPedidoId(pedidoId, produtoId);
          result.add(produto);
        } catch (_) {
          // Ignora produtos que falham ao carregar para evitar trava na UI
        }
      }
      return result;
    }
    return _produtosIniciais ?? [];
  }

  set produtos(List<PedidoProdutoModel> value) {
    _produtosIniciais = value;
    idPedidosProdutosRefs = value
        .map((x) => {'pedidoId': x.pedidoId, 'produtoId': x.id})
        .toList();
  }

  bool selected = true;
  final OrdemFreezedModel freezed;
  bool isArchived;
  int? beltIndex;
  List<OrdemHistoryModel> history;

  String get localizator => id.contains('_') ? id.split('_').first : id;

  List<PedidoModel> get pedidos {
    final pedidosIds = produtos
        .map((e) => e.pedido)
        .map((e) => e.id)
        .toSet()
        .toList();
    return pedidosIds.map<PedidoModel>((e) => BackendClient.pedidos.getById(e)).toList();
  }

  double get qtdeTotal => produtos.isEmpty
      ? 0
      : produtos.fold(
          0,
          (previousValue, element) => previousValue + element.qtde,
        );

  double quantideTotal() {
    return produtos.isEmpty
        ? 0
        : produtos.fold(
            0,
            (previousValue, element) => previousValue + element.qtde,
          );
  }

  double qtdeAguardando() {
    var where = produtos
        .where(
          (e) => e.statusView.status == PedidoProdutoStatus.aguardandoProducao,
        )
        .toList();
    return where.isEmpty
        ? 0
        : where.fold(
            0,
            (previousValue, element) => previousValue + element.qtde,
          );
  }

  double qtdeProduzindo() {
    var where = produtos
        .where((e) => e.status.status == PedidoProdutoStatus.produzindo)
        .toList();
    return where.isEmpty
        ? 0
        : where.fold(
            0,
            (previousValue, element) => previousValue + element.qtde,
          );
  }

  double qtdePronto() {
    var where = produtos
        .where((e) => e.status.status == PedidoProdutoStatus.pronto)
        .toList();
    return where.isEmpty
        ? 0
        : where.fold(
            0,
            (previousValue, element) => previousValue + element.qtde,
          );
  }

  IconData get icon {
    if (freezed.isFreezed) return Icons.stop_circle_outlined;
    switch (status) {
      case PedidoProdutoStatus.aguardandoProducao:
        return Icons.access_time;
      case PedidoProdutoStatus.produzindo:
        return Icons.build_outlined;
      case PedidoProdutoStatus.pronto:
        return Icons.check;
      default:
        return Icons.error;
    }
  }

  //  double getPrcntgPronto() {
  //   final pronto = getQtdePronto();
  //   final total = getQtdeTotal();
  //   if (total == 0) return 0;
  //   return pronto / total;
  // }

  double getPrcntgAguardando() {
    final aguardando = qtdeAguardando();
    final total = quantideTotal();
    if (total == 0) return 0;
    return aguardando / total;
  }

  double getPrcntgProduzindo() {
    final produzindo = qtdeProduzindo();
    final total = quantideTotal();
    if (total == 0) return 0;
    return produzindo / total;
  }

  double getPrcntgPronto() {
    final pronto = qtdePronto();
    final total = quantideTotal();
    if (total == 0) return 0;
    return pronto / total;
  }

  PedidoProdutoStatus get status {
    if (pedidos.isEmpty) {
      return PedidoProdutoStatus.aguardandoProducao;
    }
    if (qtdePronto() == quantideTotal()) {
      return PedidoProdutoStatus.pronto;
    } else if (qtdeProduzindo() > 0) {
      return PedidoProdutoStatus.produzindo;
    } else {
      return PedidoProdutoStatus.aguardandoProducao;
    }
  }

  bool hasProduto(String produtoId) {
    return idPedidosProdutosRefs.any((ref) {
      final id = ref['produtoId'] ?? ref['produto_id'] ?? '';
      return id == produtoId;
    });
  }

  OrdemDurationsModel? get durations => OrdemDurationsModel.getByOrdem(this);

  OrdemModel({
    required this.id,
    required this.createdAt,
    required this.produto,
    required List<PedidoProdutoModel> produtos,
    required this.freezed,
    required this.updatedAt,
    this.isArchived = false,
    this.materiaPrima,
    this.beltIndex,
    this.endAt,
    required this.history,
    this.idPedidosProdutosRefs = const [],
  })  : _produtosIniciais = produtos {
    if (idPedidosProdutosRefs.isEmpty && produtos.isNotEmpty) {
       idPedidosProdutosRefs = produtos.map((x) => {'pedidoId': x.pedidoId, 'produtoId': x.id}).toList();
    }
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'endAt': endAt?.millisecondsSinceEpoch,
    'produto': produto.toMap(),
    'idPedidosProdutos': produtos
        .map((x) => {'pedidoId': x.pedidoId, 'produtoId': x.id})
        .toList(),
    'freezed': freezed.toMap(),
    'beltIndex': beltIndex,
    'materiaPrima': materiaPrima?.toMap(),
    'isArchived': isArchived,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'history': history.map((e) => e.toJson()).toList(),
  };

  factory OrdemModel.fromMap(Map<String, dynamic> map) {
    dynamic tryDecode(dynamic value) {
      if (value is String) {
        try {
          return json.decode(value);
        } catch (_) {
          return value;
        }
      }
      return value;
    }

    final produtoRaw = tryDecode(map['produto'] ?? map['produto_raw']);
    final materiaPrimaRaw = tryDecode(map['materiaPrima'] ?? map['materia_prima_raw']);
    final freezedRaw = tryDecode(map['freezed']);
    final historyRaw = tryDecode(map['history']);
    final idPedidosProdutosRaw = tryDecode(map['idPedidosProdutos'] ?? map['id_pedidos_produtos']);

    return OrdemModel(
      id: map['id'] ?? '',
      produto: ProdutoModel.fromMap(produtoRaw),
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'])
          : map['created_at'] != null
              ? DateTime.parse(map['created_at'])
              : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : map['updated_at'] != null
              ? DateTime.parse(map['updated_at'])
              : DateTime.now(),
      endAt: map['endAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endAt'])
          : map['end_at'] != null
              ? DateTime.parse(map['end_at'])
              : null,
      produtos: [], // Será preenchido pelo idPedidosProdutosRefs via getter resiliente
      idPedidosProdutosRefs: () {
        if (idPedidosProdutosRaw == null) return <Map<String, String>>[];
        try {
          final List list = idPedidosProdutosRaw;
          return list.map((x) {
            final mapx = Map<String, dynamic>.from(x);
            return {
              'pedidoId': (mapx['pedidoId'] ?? mapx['pedido_id'] ?? '').toString(),
              'produtoId': (mapx['produtoId'] ?? mapx['produto_id'] ?? '').toString(),
            };
          }).toList();
        } catch (_) {
          return <Map<String, String>>[];
        }
      }(),
      freezed: freezedRaw != null
          ? OrdemFreezedModel.fromMap(freezedRaw)
          : OrdemFreezedModel.static().copyWith(),
      isArchived: map['isArchived'] ?? map['is_archived'] ?? false,
      beltIndex: map['beltIndex'] ?? map['belt_index'],
      materiaPrima: materiaPrimaRaw != null
          ? MateriaPrimaModel.fromMap(materiaPrimaRaw)
          : null,
      history: () {
        if (historyRaw == null) return <OrdemHistoryModel>[];
        try {
          final List list = historyRaw;
          return list.map((e) => OrdemHistoryModel.fromJson(e)).toList();
        } catch (_) {
          return <OrdemHistoryModel>[];
        }
      }(),
    );
  }

  factory OrdemModel.fromSupabaseMap(Map<String, dynamic> map) => OrdemModel.fromMap(map);

  factory OrdemModel.empty() => OrdemModel(
        id: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        produto: ProdutoModel.empty(),
        produtos: [],
        freezed: OrdemFreezedModel.static(),
        history: [],
      );

  Map<String, dynamic> toSupabaseMap() => {
    'id': id,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'end_at': endAt?.toIso8601String(),
    'produto_raw': produto.toMap(),
    'id_pedidos_produtos': idPedidosProdutosRefs,
    'freezed': freezed.toMap(),
    'is_archived': isArchived,
    'belt_index': beltIndex,
    'materia_prima_raw': materiaPrima?.toMap(),
    'history': history.map((e) => e.toJson()).toList(),
  };

  String toJson() => json.encode(toMap());

  factory OrdemModel.fromJson(String source) =>
      OrdemModel.fromMap(json.decode(source));

  OrdemModel copyWith({
    String? id,
    ProdutoModel? produto,
    DateTime? createdAt,
    ValueGetter<DateTime?>? endAt,
    List<PedidoProdutoModel>? produtos,
    OrdemFreezedModel? freezed,
    MateriaPrimaModel? materiaPrima,
    DateTime? updatedAt,
    List<OrdemHistoryModel>? history,
  }) {
    return OrdemModel(
      id: id ?? this.id,
      produto: produto ?? this.produto,
      createdAt: createdAt ?? this.createdAt,
      endAt: endAt != null ? endAt() : this.endAt,
      produtos: produtos ?? this.produtos,
      freezed: freezed ?? this.freezed,
      materiaPrima: materiaPrima ?? this.materiaPrima,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
    );
  }
}

class OrdemFreezedModel {
  bool isFreezed = false;
  TextController reason;
  final DateTime updatedAt;

  static static() => OrdemFreezedModel(
    isFreezed: false,
    reason: TextController(),
    updatedAt: DateTime.now(),
  );

  OrdemFreezedModel({
    required this.isFreezed,
    required this.reason,
    required this.updatedAt,
  });

  OrdemFreezedModel copyWith({
    bool? isFreezed,
    TextController? reason,
    DateTime? updatedAt,
  }) {
    return OrdemFreezedModel(
      isFreezed: isFreezed ?? this.isFreezed,
      reason: reason ?? this.reason,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isFreezed': isFreezed,
      'reason': reason.text,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory OrdemFreezedModel.fromMap(Map<String, dynamic> map) {
    return OrdemFreezedModel(
      isFreezed: map['isFreezed'] ?? false,
      reason: TextController(text: map['reason']),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory OrdemFreezedModel.fromJson(String source) =>
      OrdemFreezedModel.fromMap(json.decode(source));

  @override
  String toString() =>
      'OrdemFreezedModel(isFreezed: $isFreezed, reason: $reason)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OrdemFreezedModel &&
        other.isFreezed == isFreezed &&
        other.reason == reason;
  }

  @override
  int get hashCode => isFreezed.hashCode ^ reason.hashCode;
}
