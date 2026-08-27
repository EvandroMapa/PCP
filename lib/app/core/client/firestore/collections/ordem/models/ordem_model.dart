import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/ordem_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/ordem_history_type_enum.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_durations_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/utils/posicao_progresso_helper.dart';
import 'package:flutter/material.dart';

class OrdemModel {
  final String id;
  final BitolaModel produto;
  final DateTime createdAt;
  DateTime updatedAt;
  MateriaPrimaModel? materiaPrima;
  EquipamentoModel? equipamento;
  DateTime? endAt;
  List<Map<String, String>> idPedidosProdutosRefs = [];
  List<PedidoBitolaModel>? _produtosIniciais;

  List<PedidoBitolaModel> get produtos {
    if (idPedidosProdutosRefs.isNotEmpty) {
      final List<PedidoBitolaModel> result = [];
      for (var x in idPedidosProdutosRefs) {
        try {
          final pedidoId = x['pedidoId'] ?? x['pedido_id'] ?? '';
          final produtoId = x['produtoId'] ?? x['bitola_id'] ?? '';
          if (pedidoId.isEmpty || produtoId.isEmpty) continue;

          final produto =
              BackendClient.pedidos.getProdutoByPedidoId(pedidoId, produtoId);
          if (produto.id.isEmpty ||
              produto.pedido.localizador.startsWith('NOTFOUND')) {
            continue;
          }
          result.add(produto);
        } catch (_) {
          // Ignora produtos que falham ao carregar para evitar trava na UI
        }
      }
      return result;
    }
    return _produtosIniciais ?? [];
  }

  set produtos(List<PedidoBitolaModel> value) {
    _produtosIniciais = value;
    idPedidosProdutosRefs =
        value.map((x) => {'pedidoId': x.pedidoId, 'produtoId': x.id}).toList();
  }

  bool selected = true;
  final OrdemFreezedModel freezed;
  bool isArchived;
  int? beltIndex;
  List<OrdemHistoryModel> history;

  String get localizator => id.contains('_') ? id.split('_').first : id;

  List<PedidoModel> get pedidos {
    final pedidosIds =
        produtos.map((e) => e.pedido).map((e) => e.id).toSet().toList();
    return pedidosIds
        .map<PedidoModel>((e) => BackendClient.pedidos.getById(e))
        .where((p) => !p.localizador.startsWith('NOTFOUND'))
        .toList();
  }

  double get qtdeTotal => produtos.isEmpty
      ? 0
      : produtos.fold(
          0,
          (previousValue, element) => previousValue + element.qtde,
        );

  double quantideTotal() {
    if (_isModoPorOs && produtos.isNotEmpty) {
      final pedidoIds = pedidos.map((e) => e.id).toList();
      final result = calcularProgressoOrdem(pedidoIds, produto.id);
      if (result.hasData) return result.pesoTotal;
    }
    return produtos.isEmpty
        ? 0
        : produtos.fold(
            0,
            (previousValue, element) => previousValue + element.qtde,
          );
  }

  bool get _isModoPorOs =>
      PreferencesService.apontamentoProducaoCD.value == 'por_os';

  /// Verifica se todos os cards (pedido_bitolas) estão com status "pronto".
  /// Usado como fallback: se os cards já são pronto mas posições ficaram
  /// dessincronizadas, os cards são a fonte de verdade.
  bool get _todosCardsProntos =>
      produtos.isNotEmpty &&
      produtos.every((e) => e.status.status == PedidoBitolaStatus.pronto);

  double qtdeAguardando() {
    if (_isModoPorOs && produtos.isNotEmpty) {
      // Fallback: se todos os cards já estão pronto, posições divergem — cards são verdade
      if (_todosCardsProntos) return 0;
      final pedidoIds = pedidos.map((e) => e.id).toList();
      final result = calcularProgressoOrdem(pedidoIds, produto.id);
      if (result.hasData) return result.pesoAguardando;
    }
    var where = produtos
        .where(
          (e) => e.statusView.status == PedidoBitolaStatus.aguardandoProducao,
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
    if (_isModoPorOs && produtos.isNotEmpty) {
      // Fallback: se todos os cards já estão pronto, posições divergem — cards são verdade
      if (_todosCardsProntos) return 0;
      final pedidoIds = pedidos.map((e) => e.id).toList();
      final result = calcularProgressoOrdem(pedidoIds, produto.id);
      if (result.hasData) return result.pesoProduzindo;
    }
    var where = produtos
        .where((e) => e.status.status == PedidoBitolaStatus.produzindo)
        .toList();
    return where.isEmpty
        ? 0
        : where.fold(
            0,
            (previousValue, element) => previousValue + element.qtde,
          );
  }

  double qtdePronto() {
    if (_isModoPorOs && produtos.isNotEmpty) {
      // Fallback: se todos os cards já estão pronto, posições divergem — cards são verdade
      if (_todosCardsProntos) return quantideTotal();
      final pedidoIds = pedidos.map((e) => e.id).toList();
      final result = calcularProgressoOrdem(pedidoIds, produto.id);
      // Aqui usamos o percentual e multiplicamos pela quantidade total inteira
      // Pois elementos fracionados podem não refletir o total do pedido até ficarem prontos na nova UI.
      if (result.hasData) return result.pesoPronto;
    }
    var where = produtos
        .where((e) => e.status.status == PedidoBitolaStatus.pronto)
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
      case PedidoBitolaStatus.aguardandoProducao:
        return Icons.access_time;
      case PedidoBitolaStatus.produzindo:
        return Icons.build_outlined;
      case PedidoBitolaStatus.pronto:
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

  PedidoBitolaStatus get status {
    if (pedidos.isEmpty) {
      return PedidoBitolaStatus.aguardandoProducao;
    }
    final pronto = qtdePronto();
    final total = quantideTotal();

    if (total > 0 && pronto >= total) {
      return PedidoBitolaStatus.pronto;
    } else if (qtdeProduzindo() > 0 ||
        pronto > 0 ||
        produtos.any((e) =>
            e.status.status == PedidoBitolaStatus.produzindo ||
            e.status.status == PedidoBitolaStatus.pronto ||
            e.status.status == PedidoBitolaStatus.aguardaSegundaEtapa)) {
      return PedidoBitolaStatus.produzindo;
    } else {
      return PedidoBitolaStatus.aguardandoProducao;
    }
  }

  bool hasProduto(String produtoId) {
    if (produtoId.isEmpty) return false;
    return idPedidosProdutosRefs.any((ref) {
      final id =
          (ref['produtoId'] ?? ref['bitola_id'] ?? '').toString().trim();
      return id == produtoId.trim();
    });
  }

  OrdemDurationsModel? get durations => OrdemDurationsModel.getByOrdem(this);

  /// Retorna a data em que a ordem foi arquivada (último evento 'arquivada' no history).
  /// Fallback para updatedAt se não encontrar no history.
  DateTime get archivedAt {
    final evento = history
        .where((e) => e.type == OrdemHistoryTypeEnum.arquivada)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return evento.isNotEmpty ? evento.first.createdAt : updatedAt;
  }

  OrdemModel({
    required this.id,
    required this.createdAt,
    required this.produto,
    required List<PedidoBitolaModel> produtos,
    required this.freezed,
    required this.updatedAt,
    this.isArchived = false,
    this.materiaPrima,
    this.equipamento,
    this.beltIndex,
    this.endAt,
    required this.history,
    this.idPedidosProdutosRefs = const [],
  }) : _produtosIniciais = produtos {
    if (idPedidosProdutosRefs.isEmpty && produtos.isNotEmpty) {
      idPedidosProdutosRefs = produtos
          .map((x) => {'pedidoId': x.pedidoId, 'produtoId': x.id})
          .toList();
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
        'equipamento': equipamento?.toMap(),
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

    final produtoRaw = tryDecode(map['produto'] ?? map['bitola_raw']);
    final materiaPrimaRaw =
        tryDecode(map['materiaPrima'] ?? map['materia_prima_raw']);
    final freezedRaw = tryDecode(map['freezed']);
    final historyRaw = tryDecode(map['history']);
    final equipamentoRaw =
        tryDecode(map['equipamento'] ?? map['equipamento_raw']);
    final idPedidosProdutosRaw =
        tryDecode(map['idPedidosProdutos'] ?? map['id_pedidos_bitolas']);

    // Dynamic linking: busca Produto e MateriaPrima atualizados no cache reativo
    final produtoId = BitolaModel.fromMap(produtoRaw).id;
    final produto = BackendClient.bitolas.data.isNotEmpty
        ? BackendClient.bitolas.getById(produtoId)
        : BitolaModel.fromMap(produtoRaw);

    MateriaPrimaModel? materiaPrima;
    if (materiaPrimaRaw != null) {
      final mpSnapshot = MateriaPrimaModel.fromMap(materiaPrimaRaw);
      materiaPrima = BackendClient.materiaPrima.data.isNotEmpty
          ? BackendClient.materiaPrima.getById(mpSnapshot.id)
          : mpSnapshot;
    }

    EquipamentoModel? equipamento;
    if (equipamentoRaw != null) {
      final eqSnapshot = EquipamentoModel.fromMap(equipamentoRaw);
      equipamento = BackendClient.equipamentos.data.isNotEmpty
          ? BackendClient.equipamentos.getById(eqSnapshot.id)
          : eqSnapshot;
    }

    return OrdemModel(
      id: map['id'] ?? '',
      produto: produto,
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
              'pedidoId': (mapx['pedidoId'] ?? mapx['pedido_id'] ?? '')
                  .toString()
                  .trim(),
              'produtoId': (mapx['produtoId'] ?? mapx['bitola_id'] ?? '')
                  .toString()
                  .trim(),
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
      materiaPrima: materiaPrima,
      equipamento: equipamento,
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

  factory OrdemModel.fromSupabaseMap(Map<String, dynamic> map) =>
      OrdemModel.fromMap(map);

  factory OrdemModel.empty() => OrdemModel(
        id: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        produto: BitolaModel.empty(),
        produtos: [],
        freezed: OrdemFreezedModel.static(),
        history: [],
        equipamento: null,
      );

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'end_at': endAt?.toIso8601String(),
        'bitola_raw': produto.toMap(),
        'id_pedidos_bitolas': idPedidosProdutosRefs,
        'freezed': freezed.toMap(),
        'is_archived': isArchived,
        'belt_index': beltIndex,
        'materia_prima_raw': materiaPrima?.toMap(),
        'equipamento_raw': equipamento?.toMap(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  String toJson() => json.encode(toMap());

  factory OrdemModel.fromJson(String source) =>
      OrdemModel.fromMap(json.decode(source));

  OrdemModel copyWith({
    String? id,
    BitolaModel? produto,
    DateTime? createdAt,
    ValueGetter<DateTime?>? endAt,
    List<PedidoBitolaModel>? produtos,
    OrdemFreezedModel? freezed,
    MateriaPrimaModel? materiaPrima,
    EquipamentoModel? equipamento,
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
      equipamento: equipamento ?? this.equipamento,
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

// v-supabase-stable-v1.1 22
