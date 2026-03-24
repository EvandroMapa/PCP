import 'dart:convert';
import 'dart:developer';

import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/automatizacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_prioridade_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/archive/archive_model.dart';
import 'package:aco_plus/app/core/components/checklist/check_item_model.dart';
import 'package:aco_plus/app/core/components/comment/comment_model.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

class PedidoModel {
  final String id;
  final String localizador;
  final String descricao;
  final DateTime createdAt;
  DateTime? deliveryAt;
  final ClienteModel cliente;
  final ObraModel obra;
  final List<PedidoProdutoModel> produtos;
  final PedidoTipo tipo;
  List<PedidoStatusModel> statusess;
  List<PedidoStepModel> steps;
  List<TagModel> tags;
  final List<ArchiveModel> archives;
  final List<CheckItemModel> checks;
  final String? checklistId;
  final List<CommentModel> comments;
  final List<UsuarioModel> users;
  final List<PedidoHistoryModel> histories;
  int index;
  final Key key = UniqueKey();
  bool isArchived = false;
  final String planilhamento;
  final String pedidoFinanceiro;
  final String instrucoesEntrega;
  final String instrucoesFinanceiras;
  PedidoPrioridadeModel? prioridade;
  final List<String> pedidosVinculados;
  final List<String> pedidosFilhos;
  String? pai;
  bool isFilho = false;
  String? romaneio;

  factory PedidoModel.empty() => PedidoModel(
    id: HashService.get,
    localizador: 'NOTFOUND${HashService.get}',
    descricao: '',
    createdAt: DateTime.now(),
    deliveryAt: null,
    cliente: ClienteModel.empty(),
    obra: ObraModel.empty(),
    produtos: [],
    tipo: PedidoTipo.cda,
    statusess: [],
    steps: [],
    tags: [],
    checks: [],
    comments: [],
    users: [],
    index: 10000000,
    histories: [],
    isArchived: false,
    archives: [],
    checklistId: '',
    planilhamento: '',
    pedidoFinanceiro: '',
    instrucoesEntrega: '',
    instrucoesFinanceiras: '',
    prioridade: null,
    pedidosVinculados: [],
    pedidosFilhos: [],
    pai: null,
    isFilho: false,
    romaneio: null,
  );

  String get filtro => localizador + pedidoFinanceiro;

  StepModel get step => steps.isNotEmpty ? steps.last.step : StepModel.notFound;
  PedidoStatus get status => statusess.isNotEmpty ? statusess.last.status : PedidoStatus.aguardandoProducaoCD;

  bool get isChangeStatusAvailable =>
      !isAguardandoEntradaProducao() &&
      tipo == PedidoTipo.cda &&
      [
        PedidoStatus.aguardandoProducaoCDA,
        PedidoStatus.produzindoCDA,
        PedidoStatus.pronto,
      ].contains(status);

  void addStep(step) => steps.add(PedidoStepModel.create(step));

  bool isAguardandoEntradaProducao() {
    if (step.index >= (automatizacaoConfig.produtoPedidoSeparado.step?.index ?? 0)) {
      return false;
    }
    return true;
  }

  List<PedidoStatusModel> getArmacaoStatusses() {
    final statusessFiltered = <PedidoStatusModel>[];
    final status = statusess
        .where(
          (e) =>
              e.status == PedidoStatus.produzindoCD ||
              e.status == PedidoStatus.aguardandoProducaoCD,
        )
        .toList()
        .firstOrNull;
    if (status == null) return statusessFiltered;
    for (var status in statusess) {
      if (status.status != PedidoStatus.produzindoCD &&
          status.status != PedidoStatus.aguardandoProducaoCD) {
        statusessFiltered.add(status.copyWith());
      }
    }
    statusessFiltered.add(status.copyWith());
    statusessFiltered.sort((b, a) => a.createdAt.compareTo(b.createdAt));
    for (var status in statusessFiltered) {
      if (status.status == PedidoStatus.produzindoCD) {
        status.status = PedidoStatus.aguardandoProducaoCD;
      }
    }
    return statusessFiltered;
  }

  int iOfProductById(String id) {
    return produtos.indexWhere((element) => element.id == id);
  }

  PedidoModel({
    required this.id,
    required this.localizador,
    required this.descricao,
    required this.createdAt,
    required this.deliveryAt,
    required this.cliente,
    required this.obra,
    required this.produtos,
    required this.tipo,
    required this.statusess,
    required this.steps,
    required this.tags,
    required this.checks,
    required this.comments,
    required this.users,
    required this.index,
    required this.histories,
    required this.isArchived,
    required this.archives,
    required this.checklistId,
    required this.planilhamento,
    required this.pedidoFinanceiro,
    required this.instrucoesEntrega,
    required this.instrucoesFinanceiras,
    required this.prioridade,
    required this.pedidosVinculados,
    required this.pedidosFilhos,
    required this.pai,
    required this.isFilho,
    required this.romaneio,
  });


  double getQtdeDirecionada(PedidoProdutoModel produto) {
    double qtde = 0.0;
    for (final filho in getPedidosFilhos()) {
      for (final prodFilho in filho.produtos) {
        if (prodFilho.produto.id == produto.produto.id) {
          qtde += prodFilho.qtde;
        }
      }
    }
    return qtde;
  }

  PedidoProdutoStatus getPedidoProdutoStatus(PedidoProdutoModel produto) {
    PedidoProdutoStatus status = PedidoProdutoStatus.aguardandoProducao;
    final produtos = getProdutos().where(
      (e) => e.produto.id == produto.produto.id,
    );
    if (produtos.every(
      (e) => e.status.status == PedidoProdutoStatus.aguardandoProducao,
    )) {
      status = PedidoProdutoStatus.aguardandoProducao;
    }
    if (produtos.any(
      (e) => e.status.status == PedidoProdutoStatus.produzindo,
    )) {
      status = PedidoProdutoStatus.produzindo;
    }
    if (produtos.every(
      (e) => e.status.status == PedidoProdutoStatus.pronto,
    )) {
      return status;
    }
    return status;
  }

  List<PedidoProdutoModel> getProdutos() {
    if (pedidosFilhos.isNotEmpty) {
      return getPedidosFilhos().expand((e) => e.produtos).toList();
    }
    return produtos;
  }

  List<PedidoModel> getPedidosVinculados() {
    return pedidosVinculados
        .map<PedidoModel>((e) => FirestoreClient.pedidos.getById(e))
        .toList();
    // return FirestoreClient.pedidos.data
    //     .where((e) => pedidosVinculados.contains(e.id))
    //     .toList();
  }

  List<PedidoModel> getPedidosFilhos() {
    return pedidosFilhos
        .map<PedidoModel>((e) => FirestoreClient.pedidos.getById(e))
        .toList();
  }

  List<PedidoProdutoStatus> get getStatusess {
    List<PedidoProdutoStatus> statusess = [];
    for (var element in produtos) {
      statusess.add(element.status.status);
    }
    return statusess.toSet().toList();
  }

  double getQtdeTotal() {
    return getProdutos().fold(
      0.0,
      (previousValue, element) =>
          previousValue +
          (element.qtde *
              (element.produto.massaFinal > 0 ? element.produto.massaFinal : 1.0)),
    );
  }

  double getQtdeAguardandoProducao() {
    return getProdutos()
        .where(
          (e) =>
              e.statusess.last.getStatusView() ==
              PedidoProdutoStatus.aguardandoProducao,
        )
        .fold(0, (previousValue, element) => previousValue + element.qtde);
  }

  double getQtdeProduzindo() {
    return getProdutos()
        .where((e) => e.statusess.last.status == PedidoProdutoStatus.produzindo)
        .fold(0, (previousValue, element) => previousValue + element.qtde);
  }

  double getQtdePronto() {
    return getProdutos()
        .where((e) => e.statusess.last.status == PedidoProdutoStatus.pronto)
        .fold(0, (previousValue, element) => previousValue + element.qtde);
  }

  double getPrcntgAguardandoProducao() {
    final aguardandoProducao = getQtdeAguardandoProducao();
    final total = getQtdeTotal();
    if (total == 0) return 0;
    return aguardandoProducao / total;
  }

  double getPrcntgProduzindo() {
    final produzindo = getQtdeProduzindo();
    final total = getQtdeTotal();
    if (total == 0) return 0;
    return produzindo / total;
  }

  double getPrcntgPronto() {
    final pronto = getQtdePronto();
    final total = getQtdeTotal();
    if (total == 0) return 0;
    return pronto / total;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'localizador': localizador,
      'descricao': descricao,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'cliente': cliente.toMap(),
      'obra': obra.toMap(),
      'produtos': produtos.map((x) => x.toMap()).toList(),
      'tipo': tipo.index,
      'status': statusess.map((x) => x.toMap()).toList(),
      'steps': steps.map((x) => x.toMap()).toList(),
      'tags': tags.map((x) => x.toMap()).toList(),
      'deliveryAt': deliveryAt?.millisecondsSinceEpoch,
      'archives': archives.map((x) => x.toMap()).toList(),
      'checks': checks.map((x) => x.toMap()).toList(),
      'comments': comments.map((x) => x.toMap()).toList(),
      'users': users.map((x) => x.id).toList(),
      'index': index,
      'histories': histories.map((x) => x.toMap()).toList(),
      'isArchived': isArchived,
      'checklistId': checklistId,
      'planilhamento': planilhamento,
      'pedidoFinanceiro': pedidoFinanceiro,
      'instrucoesEntrega': instrucoesEntrega,
      'instrucoesFinanceiras': instrucoesFinanceiras,
      'prioridade': prioridade?.toMap(),
      'pedidosVinculados': pedidosVinculados,
      'pedidosFilhos': pedidosFilhos,
      'pai': pai,
      'isFilho': isFilho,
      'romaneio': romaneio,
    };
  }

  factory PedidoModel.fromMap(Map<String, dynamic> map) {
    return PedidoModel(
      checklistId: map['checklistId'],
      localizador: map['localizador'] ?? '',
      descricao: map['descricao'] ?? '',
      id: map['id'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      deliveryAt: map['deliveryAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['deliveryAt'])
          : null,
      cliente: ClienteModel.fromMap(map['cliente']),
      obra: getObra(map),
      tipo: PedidoTipo.values[map['tipo']],
      statusess: List<PedidoStatusModel>.from(
        map['status']?.map((x) => PedidoStatusModel.fromMap(x)) ?? [],
      ),
      produtos: List<PedidoProdutoModel>.from(
        map['produtos']?.map((x) => PedidoProdutoModel.fromMap(x)) ?? [],
      ),
      archives: List<ArchiveModel>.from(
        map['archives']?.map((x) => ArchiveModel.fromMap(x)) ?? [],
      ),
      checks: List<CheckItemModel>.from(
        map['checks']?.map((x) => CheckItemModel.fromMap(x)) ?? [],
      ),
      comments: List<CommentModel>.from(
        map['comments']?.map((x) => CommentModel.fromMap(x)) ?? [],
      ),
      steps: map['steps'] != null && map['steps'].isNotEmpty
          ? List<PedidoStepModel>.from(
              map['steps']?.map((x) => PedidoStepModel.fromMap(x)),
            )
          : [
              PedidoStepModel(
                id: HashService.get,
                step: FirestoreClient.steps.data.firstOrNull ?? StepModel.notFound,
                createdAt: DateTime.now(),
              ),
            ],
      tags: map['tags'] != null
          ? List<TagModel>.from(map['tags']?.map((x) => TagModel.fromMap(x)))
          : [],
      users: List<UsuarioModel>.from(
        map['users']?.map((x) => FirestoreClient.usuarios.getById(x)) ?? [],
      ),
      index: map['index'] ?? 0,
      histories: map['histories'] != null
          ? List<PedidoHistoryModel>.from(
              map['histories']?.map((x) => PedidoHistoryModel.fromMap(x)),
            )
          : [],
      isArchived: map['isArchived'] ?? false,
      planilhamento: map['planilhamento'] ?? '',
      pedidoFinanceiro: map['pedidoFinanceiro'] ?? '',
      instrucoesEntrega: map['instrucoesEntrega'] ?? '',
      instrucoesFinanceiras: map['instrucoesFinanceiras'] ?? '',
      prioridade: map['prioridade'] != null
          ? PedidoPrioridadeModel.fromMap(map['prioridade'])
          : null,
      pedidosVinculados: map['pedidosVinculados'] != null
          ? List<String>.from(map['pedidosVinculados'])
          : [],
      pedidosFilhos: map['pedidosFilhos'] != null
          ? List<String>.from(map['pedidosFilhos'])
          : [],
      pai: map['pai'],
      isFilho: map['isFilho'] ?? false,
      romaneio: map['romaneio'],
    );
  }

  static ObraModel getObra(Map<String, dynamic> map) {
    try {
      if (map['obra'] != null) {
        final clienteById = FirestoreClient.clientes.getById(
          map['cliente']['id'],
        );
        final obra = clienteById.obras.firstWhereOrNull(
          (e) => e.id == map['obra']['id'],
        );
        if (obra != null) {
          return obra;
        } else {
          return ObraModel.fromMap(map['obra']);
        }
      }
      return ObraModel.empty();
    } catch (e) {
      return ObraModel.empty();
    }
  }

  String toJson() => json.encode(toMap());

  factory PedidoModel.fromJson(String source) =>
      PedidoModel.fromMap(json.decode(source));

  /// Build a PedidoModel from a flat Supabase/PostgreSQL row.
  /// cliente and obra are looked up from BackendClient at parse time.
  factory PedidoModel.fromSupabaseMap(
    Map<String, dynamic> map, {
    List<Map<String, dynamic>>? statusRaw,
    List<Map<String, dynamic>>? stepsRaw,
    List<Map<String, dynamic>>? produtosRaw,
    List<String>? tagsIds,
  }) {
    // Resolve cliente and step via the BackendClient (already loaded)
    late ClienteModel cliente;
    late ObraModel obra;
    late StepModel step;
    try {
      final clienteId = (map['cliente_id'] ?? '').toString();
      final obraId = (map['obra_id'] ?? '').toString();
      final stepId = (map['step_id'] ?? '').toString();
      cliente = FirestoreClient.clientes.getById(clienteId);
      obra = cliente.obras.firstWhereOrNull((e) => e.id == obraId) ??
          ObraModel.empty();
      step = FirestoreClient.steps.getById(stepId);
      if (step == StepModel.notFound && FirestoreClient.steps.data.isNotEmpty) {
        step = FirestoreClient.steps.data.first;
      }
    } catch (_) {
      cliente = ClienteModel.empty();
      obra = ObraModel.empty();
      step = StepModel.notFound;
    }

    final produtos = produtosRaw != null
        ? produtosRaw.map((p) => PedidoProdutoModel.fromSupabaseMap(p)).toList()
        : <PedidoProdutoModel>[];

    final pedido = PedidoModel(
        id: (map['id'] ?? '').toString(),
        localizador: (map['localizador'] ?? '').toString(),
        descricao: (map['descricao'] ?? '').toString(),
        createdAt: _parseDate(map['created_at']),
        deliveryAt: map['delivery_at'] != null ? _parseDate(map['delivery_at']) : null,
        cliente: cliente,
        obra: obra,
        produtos: produtos,
        tipo: PedidoTipo.values.firstWhere(
            (e) => e.name == (map['tipo'] ?? 'cd'),
            orElse: () => PedidoTipo.cd),
        statusess: statusRaw != null
            ? statusRaw.map((s) => PedidoStatusModel.fromMap(s)).toList()
            : [
                PedidoStatusModel.create(PedidoStatus.aguardandoProducaoCD),
              ],
        steps: stepsRaw != null
            ? stepsRaw.map((e) => PedidoStepModel.fromSupabaseMap(e)).toList()
            : [
                PedidoStepModel(
                    id: (map['id'] ?? '').toString(), step: step, createdAt: DateTime.now())
              ],
        tags: tagsIds != null
            ? tagsIds.map((tid) => FirestoreClient.tags.getById(tid)).toList()
            : [],
        checks: [], // TODO: Implement checklist persistence
        comments: [], // TODO: Implement comment persistence
        users: [],
        index: int.tryParse((map['index'] ?? '0').toString()) ?? 0,
        histories: [],
        isArchived: map['is_archived'] == true,
        archives: [],
        checklistId: map['checklist_id']?.toString(),
        planilhamento: map['planilhamento']?.toString() ?? '',
        pedidoFinanceiro: map['pedido_financeiro']?.toString() ?? '',
        instrucoesEntrega: map['instrucoes_entrega']?.toString() ?? '',
        instrucoesFinanceiras: map['instrucoes_financeiras']?.toString() ?? '',
        prioridade: null,
        pedidosVinculados: [],
        pedidosFilhos: [],
        pai: null,
        isFilho: false,
        romaneio: null);
    
    return pedido;
  }

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is DateTime) return val;
    return DateTime.tryParse(val.toString()) ?? DateTime.now();
  }

  Map<String, dynamic> toSupabaseMap() => {
    'id': id,
    'localizador': localizador,
    'descricao': descricao,
    'tipo': tipo.name,
    'cliente_id': cliente.id,
    'obra_id': obra.id,
    'step_id': steps.isNotEmpty ? steps.last.step.id : null,
    'status': statusess.isNotEmpty ? statusess.last.status.name : null,
    'is_archived': isArchived,
    'checklist_id': checklistId,
    'planilhamento': planilhamento,
    'pedido_financeiro': pedidoFinanceiro,
    'instrucoes_entrega': instrucoesEntrega,
    'instrucoes_financeiras': instrucoesFinanceiras,
    'delivery_at': deliveryAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'index': index,
  };

  PedidoModel copyWith({
    String? id,
    String? localizador,
    String? descricao,
    DateTime? createdAt,
    ClienteModel? cliente,
    ObraModel? obra,
    List<PedidoProdutoModel>? produtos,
    PedidoTipo? tipo,
    List<PedidoStatusModel>? statusess,
    DateTime? deliveryAt,
    List<PedidoStepModel>? steps,
    List<TagModel>? tags,
    List<CheckItemModel>? checks,
    List<CommentModel>? comments,
    List<UsuarioModel>? users,
    int? index,
    List<PedidoHistoryModel>? histories,
    bool? isArchived,
    List<ArchiveModel>? archives,
    String? checklistId,
    String? planilhamento,
    String? pedidoFinanceiro,
    String? instrucoesEntrega,
    String? instrucoesFinanceiras,
    PedidoPrioridadeModel? prioridade,
    List<String>? pedidosVinculados,
    List<String>? pedidosFilhos,
    String? pai,
    bool? isFilho,
    String? romaneio,
  }) {
    return PedidoModel(
      id: id ?? this.id,
      checklistId: checklistId ?? this.checklistId,
      comments: comments ?? this.comments,
      checks: checks ?? this.checks,
      localizador: localizador ?? this.localizador,
      descricao: descricao ?? this.descricao,
      createdAt: createdAt ?? this.createdAt,
      cliente: cliente ?? this.cliente,
      obra: obra ?? this.obra,
      produtos: produtos ?? this.produtos,
      tipo: tipo ?? this.tipo,
      statusess: statusess ?? this.statusess,
      deliveryAt: deliveryAt ?? this.deliveryAt,
      steps: steps ?? this.steps,
      tags: tags ?? this.tags,
      users: users ?? this.users,
      index: index ?? this.index,
      histories: histories ?? this.histories,
      isArchived: isArchived ?? this.isArchived,
      archives: archives ?? this.archives,
      planilhamento: planilhamento ?? this.planilhamento,
      pedidoFinanceiro: pedidoFinanceiro ?? this.pedidoFinanceiro,
      instrucoesEntrega: instrucoesEntrega ?? this.instrucoesEntrega,
      instrucoesFinanceiras:
          instrucoesFinanceiras ?? this.instrucoesFinanceiras,
      prioridade: prioridade ?? this.prioridade,
      pedidosVinculados: pedidosVinculados ?? this.pedidosVinculados,
      pedidosFilhos: pedidosFilhos ?? this.pedidosFilhos,
      pai: pai ?? this.pai,
      isFilho: isFilho ?? this.isFilho,
      romaneio: romaneio ?? this.romaneio,
    );
  }

  @override
  String toString() {
    return 'PedidoModel(id: id, localizador: $localizador, descricao: $descricao, createdAt: $createdAt, deliveryAt: $deliveryAt, cliente: $cliente, obra: $obra, produtos: $produtos, tipo: $tipo, statusess: $statusess, steps: $steps, pedidosVinculados: $pedidosVinculados)';
  }
}
