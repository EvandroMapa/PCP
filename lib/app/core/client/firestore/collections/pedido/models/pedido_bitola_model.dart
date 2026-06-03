import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/ordem_history_type_enum.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/types/ordem_history_type_despausada_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/types/ordem_history_type_pausada_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/types/ordem_history_type_status_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/enums/obra_status.dart';

import 'package:collection/collection.dart';

class PedidoProdutoTurno {
  final String produtoId;
  final String pedidoId;
  final String pedidoProdutoId;
  final String ordemId;
  final Duration duration;
  final PedidoProdutoHistory start;
  final PedidoProdutoHistory? end;

  PedidoProdutoTurno({
    required this.produtoId,
    required this.pedidoId,
    required this.pedidoProdutoId,
    required this.ordemId,
    required this.start,
    required this.duration,
    this.end,
  });
}

enum PedidoProdutoHistoryType {
  pause,
  unpause;

  String get label {
    switch (this) {
      case PedidoProdutoHistoryType.pause:
        return 'Iniciado ás';
      case PedidoProdutoHistoryType.unpause:
        return 'Finalizado ás';
    }
  }
}

class PedidoProdutoHistory {
  final PedidoProdutoHistoryType type;
  final DateTime date;

  PedidoProdutoHistory({required this.type, required this.date});
}

class PedidoBitolaModel {
  final String id;
  final String pedidoId;
  final String clienteId;
  final String obraId;
  final BitolaModel produto;
  final List<PedidoBitolaStatusModel> statusess;
  final double qtde;
  final double qtdeOriginal;
  bool isSelected = true;
  bool isAvailable = true;
  bool isPaused = false;
  MateriaPrimaModel? materiaPrima;

  // New financial fields
  final double valorUnitario;
  final double valorTotal;

  List<PedidoProdutoTurno> getTurnos(OrdemModel ordem) {
    final turnos = <PedidoProdutoTurno>[];

    final alteracoesStatus = ordem.history
        .where(
      (e) =>
          e.type == OrdemHistoryTypeEnum.statusProdutoAlterada ||
          e.type == OrdemHistoryTypeEnum.pausada ||
          e.type == OrdemHistoryTypeEnum.despausada,
    )
        .where((e) {
      switch (e.type) {
        case OrdemHistoryTypeEnum.statusProdutoAlterada:
          final data = e.data as OrdemHistoryTypeStatusBitolaModel;
          return data.statusProdutos.produtos.any((e) => e.id == id);
        case OrdemHistoryTypeEnum.pausada:
          final data = e.data as OrdemHistoryTypePausadaModel;
          return data.pedidoProdutoId == id;
        case OrdemHistoryTypeEnum.despausada:
          final data = e.data as OrdemHistoryTypeDespausadaModel;
          return data.pedidoProdutoId == id;
        default:
          return false;
      }
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    DateTime? inicioTurnoAtual;
    bool estaProduzindo = false;
    bool estaPausado = false;

    for (final evento in alteracoesStatus) {
      switch (evento.type) {
        case OrdemHistoryTypeEnum.statusProdutoAlterada:
          final data = evento.data as OrdemHistoryTypeStatusBitolaModel;
          final novoStatus = data.statusProdutos.status;

          if (novoStatus == PedidoBitolaStatus.produzindo && !estaProduzindo) {
            inicioTurnoAtual = evento.createdAt;
            estaProduzindo = true;
            estaPausado = false;
          } else if (novoStatus == PedidoBitolaStatus.pronto &&
              estaProduzindo) {
            if (inicioTurnoAtual != null) {
              final duracao = evento.createdAt.difference(inicioTurnoAtual);
              turnos.add(
                PedidoProdutoTurno(
                  duration: duracao,
                  start: PedidoProdutoHistory(
                    type: PedidoProdutoHistoryType.pause,
                    date: inicioTurnoAtual,
                  ),
                  end: PedidoProdutoHistory(
                    type: PedidoProdutoHistoryType.unpause,
                    date: evento.createdAt,
                  ),
                  produtoId: produto.id,
                  pedidoId: pedidoId,
                  pedidoProdutoId: id,
                  ordemId: ordem.id,
                ),
              );
            }
            inicioTurnoAtual = null;
            estaProduzindo = false;
            estaPausado = false;
          } else if (estaProduzindo &&
              novoStatus != PedidoBitolaStatus.produzindo &&
              novoStatus != PedidoBitolaStatus.pronto) {
            estaProduzindo = false;
            inicioTurnoAtual = null;
            estaPausado = false;
          }
          break;

        case OrdemHistoryTypeEnum.pausada:
          if (estaProduzindo && !estaPausado) {
            if (inicioTurnoAtual != null) {
              final duracao = evento.createdAt.difference(inicioTurnoAtual);
              turnos.add(
                PedidoProdutoTurno(
                  duration: duracao,
                  start: PedidoProdutoHistory(
                    type: PedidoProdutoHistoryType.pause,
                    date: inicioTurnoAtual,
                  ),
                  end: PedidoProdutoHistory(
                    type: PedidoProdutoHistoryType.unpause,
                    date: evento.createdAt,
                  ),
                  produtoId: produto.id,
                  pedidoId: pedidoId,
                  pedidoProdutoId: id,
                  ordemId: ordem.id,
                ),
              );
            }
            estaPausado = true;
            inicioTurnoAtual = null;
          }
          break;

        case OrdemHistoryTypeEnum.despausada:
          if (estaProduzindo && estaPausado) {
            inicioTurnoAtual = evento.createdAt;
            estaPausado = false;
          }
          break;

        default:
          break;
      }
    }

    if (estaProduzindo && inicioTurnoAtual != null && !estaPausado) {
      final duracao = DateTime.now().difference(inicioTurnoAtual);
      turnos.add(
        PedidoProdutoTurno(
          duration: duracao,
          start: PedidoProdutoHistory(
            type: PedidoProdutoHistoryType.pause,
            date: inicioTurnoAtual,
          ),
          produtoId: produto.id,
          pedidoId: pedidoId,
          pedidoProdutoId: id,
          ordemId: ordem.id,
        ),
      );
    }
    return turnos;
  }

  factory PedidoBitolaModel.empty(PedidoModel pedido) => PedidoBitolaModel(
        id: '',
        pedidoId: pedido.id,
        clienteId: pedido.cliente.id,
        obraId: pedido.obra.id,
        produto: BitolaModel.empty(),
        statusess: [PedidoBitolaStatusModel.empty()],
        qtde: 0,
        qtdeOriginal: 0,
        isPaused: false,
        valorUnitario: 0.0,
        valorTotal: 0.0,
      );
  PedidoModel get pedido => FirestoreClient.pedidos.getById(pedidoId);
  bool get isAvailableToChanges => status.status.index < 2;
  bool get hasOrder => status.status == PedidoBitolaStatus.separado;

  ClienteModel get cliente => FirestoreClient.clientes.getById(clienteId);
  ObraModel get obra =>
      cliente.obras.firstWhereOrNull((e) => e.id == obraId) ??
      ObraModel(
        id: id,
        descricao: 'Indefinida',
        telefoneFixo: '',
        endereco: null,
        status: ObraStatus.emAndamento,
      );

  PedidoBitolaStatusModel get status => statusess.isNotEmpty
      ? statusess.last
      : PedidoBitolaStatusModel.create(PedidoBitolaStatus.pronto);

  PedidoBitolaStatusModel get statusView => status.copyWith(
        status: status.status == PedidoBitolaStatus.separado
            ? PedidoBitolaStatus.aguardandoProducao
            : status.status,
      );

  PedidoBitolaModel({
    required this.id,
    required this.pedidoId,
    required this.clienteId,
    required this.obraId,
    required this.produto,
    required this.statusess,
    required this.qtde,
    required this.qtdeOriginal,
    this.isAvailable = true,
    this.isSelected = true,
    this.materiaPrima,
    this.isPaused = false,
    this.valorUnitario = 0.0,
    this.valorTotal = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pedidoId': pedidoId,
      'clienteId': clienteId,
      'obraId': obraId,
      'produto': produto.toMap(),
      'statusess': statusess.map((x) => x.toMap()).toList(),
      'qtde': qtde,
      'qtdeOriginal': qtdeOriginal,
      'materiaPrima': materiaPrima?.toMap(),
      'isPaused': isPaused,
      'valor_unitario': valorUnitario,
      'valor_total': valorTotal,
    };
  }

  factory PedidoBitolaModel.fromMap(Map<String, dynamic> map) {
    return PedidoBitolaModel(
      id: map['id'] ?? '',
      pedidoId: map['pedidoId'] ?? '',
      clienteId: map['clienteId'] ?? '',
      obraId: map['obraId'] ?? '',
      produto: BitolaModel.fromMap(map['produto']),
      statusess: map['statusess'] != null
          ? List<PedidoBitolaStatusModel>.from(
              map['statusess']?.map((x) => PedidoBitolaStatusModel.fromMap(x)),
            )
          : [PedidoBitolaStatusModel.empty()],
      qtde: map['qtde'] != null ? double.parse(map['qtde'].toString()) : 0.0,
      qtdeOriginal: map['qtdeOriginal'] != null ? double.parse(map['qtdeOriginal'].toString()) : (map['qtde'] != null ? double.parse(map['qtde'].toString()) : 0.0),
      materiaPrima: map['materiaPrima'] != null
          ? MateriaPrimaModel.fromMap(map['materiaPrima'])
          : null,
      isPaused: map['isPaused'] ?? false,
      valorUnitario: (map['valor_unitario'] ?? 0.0).toDouble(),
      valorTotal: (map['valor_total'] ?? 0.0).toDouble(),
    );
  }

  String toJson() => json.encode(toMap());

  factory PedidoBitolaModel.fromJson(String source) =>
      PedidoBitolaModel.fromMap(json.decode(source));

  Map<String, dynamic> toSupabaseMap(String pedidoId) {
    return {
      'id': id,
      'id_id': id,
      'pedido_id': pedidoId,
      'cliente_id': clienteId,
      'obra_id': obraId,
      'quantidade': qtde,
      'qtde': qtde,
      'qtde_original': qtdeOriginal,
      'bitola_id': produto.id,
      'unidade': '',
      'status': statusess.isNotEmpty ? statusess.last.status.name : 'separado',
      'bitola_raw': produto.toMap(),
      'materia_prima_raw': materiaPrima?.toMap(),
      'statusess_raw': statusess.map((e) => e.toMap()).toList(),
      'valor_unitario': valorUnitario,
      'valor_total': valorTotal,
    };
  }

  factory PedidoBitolaModel.fromSupabaseMap(Map<String, dynamic> map) {
    // produto_raw é prioritário; se não existir, busca pelo produto_id no cache local
    BitolaModel produto = BitolaModel.empty();
    try {
      if (map['bitola_raw'] != null) {
        final rawMap = map['bitola_raw'] is String
            ? json.decode(map['bitola_raw'])
            : map['bitola_raw'];
        produto = BitolaModel.fromMap(Map<String, dynamic>.from(rawMap));
      } else {
        final produtoId = (map['bitola_id'] ?? '').toString();
        if (produtoId.isNotEmpty) {
          produto = FirestoreClient.bitolas.data.firstWhere(
            (e) => e.id == produtoId,
            orElse: () => BitolaModel.empty(),
          );
        }
      }
    } catch (_) {}

    // statusess_raw: JSArray<dynamic> no Flutter Web não pode ser cast direto.
    // Usar List.from() para criar lista Dart nativa antes do .map()
    List<PedidoBitolaStatusModel> statusess = [
      PedidoBitolaStatusModel.empty()
    ];
    try {
      if (map['statusess_raw'] != null) {
        final rawList = map['statusess_raw'] is String
            ? json.decode(map['statusess_raw']) as List
            : map['statusess_raw'] as List;
        statusess = List.from(rawList)
            .map((e) =>
                PedidoBitolaStatusModel.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      // Falha silenciosa ou log apropriado
    }

    // materia_prima_raw: mesmo padrão robusto
    MateriaPrimaModel? materiaPrima;
    try {
      if (map['materia_prima_raw'] != null) {
        final rawMap = map['materia_prima_raw'] is String
            ? json.decode(map['materia_prima_raw'])
            : map['materia_prima_raw'];
        materiaPrima =
            MateriaPrimaModel.fromMap(Map<String, dynamic>.from(rawMap));
      }
    } catch (_) {}

    return PedidoBitolaModel(
      id: (map['id'] ?? map['id_id'] ?? '').toString(),
      qtde: _parseNum(map['quantidade'] ?? map['qtde']),
      qtdeOriginal: _parseNum(map['qtde_original'] ?? map['quantidade'] ?? map['qtde']),
      produto: produto,
      materiaPrima: materiaPrima,
      pedidoId: (map['pedido_id'] ?? '').toString(),
      clienteId: (map['cliente_id'] ?? '').toString(),
      obraId: (map['obra_id'] ?? '').toString(),
      statusess:
          statusess.isNotEmpty ? statusess : [PedidoBitolaStatusModel.empty()],
      valorUnitario: _parseNum(map['valor_unitario']),
      valorTotal: _parseNum(map['valor_total']),
    );
  }

  static double _parseNum(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  PedidoBitolaModel copyWith({
    String? id,
    String? pedidoId,
    String? clienteId,
    String? obraId,
    BitolaModel? produto,
    List<PedidoBitolaStatusModel>? statusess,
    double? qtde,
    double? qtdeOriginal,
    bool? isAvailable,
    bool? isSelected,
    MateriaPrimaModel? materiaPrima,
    bool? isPaused,
    double? valorUnitario,
    double? valorTotal,
  }) {
    return PedidoBitolaModel(
      id: id ?? this.id,
      pedidoId: pedidoId ?? this.pedidoId,
      clienteId: clienteId ?? this.clienteId,
      obraId: obraId ?? this.obraId,
      produto: produto ?? this.produto,
      statusess: statusess ?? this.statusess,
      qtde: qtde ?? this.qtde,
      qtdeOriginal: qtdeOriginal ?? this.qtdeOriginal,
      isAvailable: isAvailable ?? this.isAvailable,
      isSelected: isSelected ?? this.isSelected,
      materiaPrima: materiaPrima ?? this.materiaPrima,
      isPaused: isPaused ?? this.isPaused,
      valorUnitario: valorUnitario ?? this.valorUnitario,
      valorTotal: valorTotal ?? this.valorTotal,
    );
  }
}
