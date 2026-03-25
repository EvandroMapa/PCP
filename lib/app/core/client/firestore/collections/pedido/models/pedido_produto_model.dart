import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/ordem_history_type_enum.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/types/ordem_history_type_despausada_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/types/ordem_history_type_pausada_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/types/ordem_history_type_status_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/enums/obra_status.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:collection/collection.dart';

class PedidoProdutoModel {
  final String id;
  final String pedidoId;
  final String clienteId;
  final String obraId;
  final ProdutoModel produto;
  final List<PedidoProdutoStatusModel> statusess;
  final double qtde;
  final double valorUnitario;
  final double valorTotal;
  bool isSelected = true;
  bool isAvailable = true;
  bool isPaused = false;
  MateriaPrimaModel? materiaPrima;

  factory PedidoProdutoModel.empty(PedidoModel pedido) => PedidoProdutoModel(
    id: HashService.get,
    pedidoId: pedido.id,
    clienteId: pedido.cliente.id,
    obraId: pedido.obra.id,
    produto: ProdutoModel.empty(),
    statusess: [PedidoProdutoStatusModel.empty()],
    qtde: 0,
    valorUnitario: 0,
    valorTotal: 0,
    isPaused: false,
  );

  PedidoModel get pedido => FirestoreClient.pedidos.getById(pedidoId);
  bool get isAvailableToChanges => status.status.index < 2;
  bool get hasOrder => status.status == PedidoProdutoStatus.separado;

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

  PedidoProdutoStatusModel get status => statusess.isNotEmpty
      ? statusess.last
      : PedidoProdutoStatusModel.create(PedidoProdutoStatus.pronto);

  PedidoProdutoStatusModel get statusView => status.copyWith(
    status: status.status == PedidoProdutoStatus.separado
        ? PedidoProdutoStatus.aguardandoProducao
        : status.status,
  );

  PedidoProdutoModel({
    required this.id,
    required this.pedidoId,
    required this.clienteId,
    required this.obraId,
    required this.produto,
    required this.statusess,
    required this.qtde,
    this.valorUnitario = 0,
    this.valorTotal = 0,
    this.isAvailable = true,
    this.isSelected = true,
    this.materiaPrima,
    this.isPaused = false,
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
      'valorUnitario': valorUnitario,
      'valorTotal': valorTotal,
      'materiaPrima': materiaPrima?.toMap(),
      'isPaused': isPaused,
    };
  }

  factory PedidoProdutoModel.fromMap(Map<String, dynamic> map) {
    return PedidoProdutoModel(
      id: map['id'] ?? '',
      pedidoId: map['pedidoId'] ?? '',
      clienteId: map['clienteId'] ?? '',
      obraId: map['obraId'] ?? '',
      produto: ProdutoModel.fromMap(map['produto']),
      statusess: map['statusess'] != null
          ? List<PedidoProdutoStatusModel>.from(
              map['statusess']?.map((x) => PedidoProdutoStatusModel.fromMap(x)),
            )
          : [PedidoProdutoStatusModel.empty()],
      qtde: map['qtde'] != null ? double.parse(map['qtde'].toString()) : 0.0,
      valorUnitario: map['valorUnitario'] != null ? double.parse(map['valorUnitario'].toString()) : 0.0,
      valorTotal: map['valorTotal'] != null ? double.parse(map['valorTotal'].toString()) : 0.0,
      materiaPrima: map['materiaPrima'] != null
          ? MateriaPrimaModel.fromMap(map['materiaPrima'])
          : null,
      isPaused: map['isPaused'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory PedidoProdutoModel.fromJson(String source) =>
      PedidoProdutoModel.fromMap(json.decode(source));

  Map<String, dynamic> toSupabaseMap(String pedidoId) {
    return {
      'id': id,
      'id_id': id,
      'pedido_id': pedidoId,
      'cliente_id': clienteId,
      'obra_id': obraId,
      'quantidade': qtde,
      'qtde': qtde,
      'valor_unitario': valorUnitario,
      'valor_total': valorTotal,
      'produto_id': produto.id,
      'unidade': '',
      'status': statusess.isNotEmpty ? statusess.last.status.name : 'separado',
      'produto_raw': produto.toMap(),
      'materia_prima_raw': materiaPrima?.toMap(),
      'statusess_raw': statusess.map((e) => e.toMap()).toList(),
    };
  }

  factory PedidoProdutoModel.fromSupabaseMap(Map<String, dynamic> map) {
    try {
      return PedidoProdutoModel(
        id: (map['id'] ?? map['id_id'] ?? '').toString(),
        qtde: double.tryParse((map['quantidade'] ?? map['qtde'] ?? '0').toString()) ?? 0.0,
        valorUnitario: double.tryParse((map['valor_unitario'] ?? '0').toString()) ?? 0.0,
        valorTotal: double.tryParse((map['valor_total'] ?? '0').toString()) ?? 0.0,
        produto: map['produto_raw'] != null 
            ? ProdutoModel.fromMap(map['produto_raw'] is String ? json.decode(map['produto_raw']) : map['produto_raw']) 
            : ProdutoModel.empty(),
        materiaPrima: map['materia_prima_raw'] != null 
            ? MateriaPrimaModel.fromMap(map['materia_prima_raw'] is String ? json.decode(map['materia_prima_raw']) : map['materia_prima_raw']) 
            : null,
        pedidoId: (map['pedido_id'] ?? '').toString(),
        clienteId: (map['cliente_id'] ?? '').toString(),
        obraId: (map['obra_id'] ?? '').toString(),
        statusess: map['statusess_raw'] != null
            ? (map['statusess_raw'] is String ? json.decode(map['statusess_raw']) : map['statusess_raw'] as List)
                .map((e) => PedidoProdutoStatusModel.fromMap(e))
                .toList()
            : [PedidoProdutoStatusModel.empty()],
      );
    } catch (e) {
      print('Error parsing PedidoProdutoModel from Supabase: $e');
      return PedidoProdutoModel(
        id: (map['id'] ?? '').toString(),
        pedidoId: (map['pedido_id'] ?? '').toString(),
        clienteId: '',
        obraId: '',
        produto: ProdutoModel.empty(),
        statusess: [PedidoProdutoStatusModel.empty()],
        qtde: 0,
      );
    }
  }

  PedidoProdutoModel copyWith({
    String? id,
    String? pedidoId,
    String? clienteId,
    String? obraId,
    ProdutoModel? produto,
    List<PedidoProdutoStatusModel>? statusess,
    double? qtde,
    double? valorUnitario,
    double? valorTotal,
    bool? isAvailable,
    bool? isSelected,
    MateriaPrimaModel? materiaPrima,
    bool? isPaused,
  }) {
    return PedidoProdutoModel(
      id: id ?? this.id,
      pedidoId: pedidoId ?? this.pedidoId,
      clienteId: clienteId ?? this.clienteId,
      obraId: obraId ?? this.obraId,
      produto: produto ?? this.produto,
      statusess: statusess ?? this.statusess,
      qtde: qtde ?? this.qtde,
      valorUnitario: valorUnitario ?? this.valorUnitario,
      valorTotal: valorTotal ?? this.valorTotal,
      isAvailable: isAvailable ?? this.isAvailable,
      isSelected: isSelected ?? this.isSelected,
      materiaPrima: materiaPrima ?? this.materiaPrima,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}
