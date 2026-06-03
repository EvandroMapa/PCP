import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_arquivo_model.dart';
import 'package:flutter/material.dart';

// ─── STATUS DO ELEMENTO w───────────────────────────────────────────────────────
enum ElementoStatus {
  aguardando,
  armando,
  pronto;

  String get label {
    switch (this) {
      case ElementoStatus.aguardando:
        return 'Aguardando';
      case ElementoStatus.armando:
        return 'Armando';
      case ElementoStatus.pronto:
        return 'Pronto';
    }
  }

  Color get color {
    switch (this) {
      case ElementoStatus.aguardando:
        return Colors.grey[400]!;
      case ElementoStatus.armando:
        return Colors.yellow[700]!;
      case ElementoStatus.pronto:
        return Colors.green[600]!;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ElementoStatus.aguardando:
        return Colors.grey[100]!;
      case ElementoStatus.armando:
        return Colors.yellow[50]!;
      case ElementoStatus.pronto:
        return Colors.green[50]!;
    }
  }
}

// ─── STATUS DA POSIÇÃO (produção CD) ──────────────────────────────────────────
enum PosicaoStatus {
  aguardando,
  produzindo,
  pronto;

  String get label {
    switch (this) {
      case PosicaoStatus.aguardando:
        return 'Aguardando';
      case PosicaoStatus.produzindo:
        return 'Produzindo';
      case PosicaoStatus.pronto:
        return 'Pronto';
    }
  }

  Color get color {
    switch (this) {
      case PosicaoStatus.aguardando:
        return Colors.grey[400]!;
      case PosicaoStatus.produzindo:
        return Colors.orange[700]!;
      case PosicaoStatus.pronto:
        return Colors.green[600]!;
    }
  }
}

// ─── MEDIDA VARIÁVEL DE POSIÇÃO ───────────────────────────────────────────────
class PosicaoMedidaModel {
  final String id;
  final String posicaoId;
  final double comprUnit; // comprimento unitário calculado
  final double comprCorte; // comprimento de corte calculado
  final int qtde; // multiplicador (ex: 2 do "16x2")
  final DateTime createdAt;

  PosicaoMedidaModel({
    required this.id,
    required this.posicaoId,
    required this.comprUnit,
    required this.comprCorte,
    this.qtde = 1,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory PosicaoMedidaModel.fromSupabaseMap(Map<String, dynamic> map) {
    return PosicaoMedidaModel(
      id: (map['id'] ?? '').toString(),
      posicaoId: (map['posicao_id'] ?? '').toString(),
      comprUnit: double.tryParse((map['compr_unit'] ?? '0').toString()) ?? 0.0,
      comprCorte: double.tryParse((map['compr_corte'] ?? '0').toString()) ?? 0.0,
      qtde: int.tryParse((map['qtde'] ?? '1').toString()) ?? 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'posicao_id': posicaoId,
        'compr_unit': comprUnit,
        'compr_corte': comprCorte,
        'qtde': qtde,
      };
}

// ─── POSIÇÃO / OS ─────────────────────────────────────────────────────────────
class ElementoPosicaoModel {
  final String id;
  final String elementoId;
  final String nome; // nome da posição (ex: "Pilar P1")
  final String numeroOs; // número da OS (ex: "OS 1", "001")
  final String produtoId;
  BitolaModel? produto; // bitola do catálogo
  final double pesoKg;
  final int qtde; // quantidade total de peças/barras na posição
  final double comprUnit; // comprimento unitário (fixo ou 0 se variável)
  final double comprCorte; // comprimento de corte (fixo ou 0 se variável)
  PosicaoStatus status; // status de produção CD
  final DateTime createdAt;
  List<PosicaoMedidaModel> medidas; // medidas variáveis (vazio se comprimento fixo)

  ElementoPosicaoModel({
    required this.id,
    required this.elementoId,
    required this.nome,
    required this.numeroOs,
    required this.produtoId,
    required this.pesoKg,
    required this.createdAt,
    this.qtde = 0,
    this.comprUnit = 0,
    this.comprCorte = 0,
    this.produto,
    this.status = PosicaoStatus.aguardando,
    List<PosicaoMedidaModel>? medidas,
  }) : medidas = medidas ?? [];

  /// Se esta posição tem comprimentos variáveis
  bool get isVariavel => medidas.isNotEmpty;

  factory ElementoPosicaoModel.fromSupabaseMap(
    Map<String, dynamic> map, {
    List<Map<String, dynamic>>? medidasRaw,
  }) {
    final produtoId = (map['bitola_id'] ?? '').toString();
    return ElementoPosicaoModel(
      id: (map['id'] ?? '').toString(),
      elementoId: (map['elemento_id'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      numeroOs: (map['numero_os'] ?? '').toString(),
      produtoId: produtoId,
      pesoKg: double.tryParse((map['peso_kg'] ?? '0').toString()) ?? 0.0,
      qtde: int.tryParse((map['qtde'] ?? '0').toString()) ?? 0,
      comprUnit: double.tryParse((map['compr_unit'] ?? '0').toString()) ?? 0.0,
      comprCorte: double.tryParse((map['compr_corte'] ?? '0').toString()) ?? 0.0,
      status: PosicaoStatus.values.firstWhere(
          (e) => e.name == (map['status'] ?? 'aguardando'),
          orElse: () => PosicaoStatus.aguardando),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      produto: FirestoreClient.bitolas.data
          .where((p) => p.id == produtoId)
          .firstOrNull,
      medidas: (medidasRaw ?? [])
          .map((m) => PosicaoMedidaModel.fromSupabaseMap(m))
          .toList(),
    );
  }

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'elemento_id': elementoId,
        'nome': nome,
        'numero_os': numeroOs,
        'bitola_id': produtoId,
        'peso_kg': pesoKg,
        'qtde': qtde,
        'compr_unit': comprUnit,
        'compr_corte': comprCorte,
        'status': status.name,
      };
}

// ─── ELEMENTO ─────────────────────────────────────────────────────────────────
class ElementoModel {
  final String id;
  final String pedidoId;
  final String nome;
  final int qtde;
  final int qtdePronto; // Quantas peças já foram concluídas (para qtde > 1)
  final DateTime createdAt;
  final ElementoStatus status;
  List<ElementoPosicaoModel> posicoes;
  List<ElementoArquivoModel> arquivos;

  ElementoModel({
    required this.id,
    required this.pedidoId,
    required this.nome,
    required this.qtde,
    required this.createdAt,
    required this.posicoes,
    required this.arquivos,
    this.qtdePronto = 0,
    this.status = ElementoStatus.aguardando,
  });

  /// Peso total calculado (soma das posições * qtde)
  double get pesoTotal => posicoes.fold(0.0, (sum, p) => sum + p.pesoKg) * qtde;

  /// Peso unitário de um elemento (soma das posições)
  double get pesoUnitario => posicoes.fold(0.0, (sum, p) => sum + p.pesoKg);

  ElementoModel copyWith({
    String? id,
    String? pedidoId,
    String? nome,
    int? qtde,
    int? qtdePronto,
    DateTime? createdAt,
    ElementoStatus? status,
    List<ElementoPosicaoModel>? posicoes,
    List<ElementoArquivoModel>? arquivos,
  }) {
    return ElementoModel(
      id: id ?? this.id,
      pedidoId: pedidoId ?? this.pedidoId,
      nome: nome ?? this.nome,
      qtde: qtde ?? this.qtde,
      qtdePronto: qtdePronto ?? this.qtdePronto,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      posicoes: posicoes ?? this.posicoes,
      arquivos: arquivos ?? this.arquivos,
    );
  }

  /// Peso agrupado por produto (bitola)
  Map<String, double> get pesoPorBitola {
    final map = <String, double>{};
    for (final p in posicoes) {
      map[p.produtoId] = (map[p.produtoId] ?? 0.0) + p.pesoKg;
    }
    return map;
  }

  /// Se tem conclusão parcial (qtde > 1 e ainda não todos prontos)
  bool get isProntoParcial => qtdePronto > 0 && qtdePronto < qtde;

  /// Progresso de conclusão (0.0 a 1.0)
  double get progressoPronto =>
      qtde > 0 ? (qtdePronto / qtde).clamp(0.0, 1.0) : 0.0;

  /// Peso já concluído proporcionalmente
  double get pesoPronto => pesoTotal * progressoPronto;

  factory ElementoModel.fromSupabaseMap(
    Map<String, dynamic> map, {
    List<Map<String, dynamic>>? posicoesRaw,
    List<Map<String, dynamic>>? arquivosRaw,
    List<Map<String, dynamic>>? medidasRaw,
  }) {
    final posicoes = (posicoesRaw ?? []).map((p) {
      final pId = (p['id'] ?? '').toString();
      final medidasDaPosicao = (medidasRaw ?? [])
          .where((m) => m['posicao_id'].toString() == pId)
          .toList();
      return ElementoPosicaoModel.fromSupabaseMap(p, medidasRaw: medidasDaPosicao);
    }).toList();
    final arquivos = (arquivosRaw ?? [])
        .map((a) => ElementoArquivoModel.fromMap(a))
        .toList();
    return ElementoModel(
      id: (map['id'] ?? '').toString(),
      pedidoId: (map['pedido_id'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      qtde: int.tryParse((map['qtde'] ?? '1').toString()) ?? 1,
      qtdePronto: int.tryParse((map['qtde_pronto'] ?? '0').toString()) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      posicoes: posicoes,
      arquivos: arquivos,
      status: ElementoStatus.values.firstWhere(
          (e) => e.name == (map['status'] ?? 'aguardando'),
          orElse: () => ElementoStatus.aguardando),
    );
  }

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'pedido_id': pedidoId,
        'nome': nome,
        'qtde': qtde,
        'qtde_pronto': qtdePronto,
        'status': status.name,
      };
}

// ─── MODELOS DE CRIAÇÃO / EDIÇÃO (para formulário) ───────────────────────────

class PosicaoMedidaCreateModel {
  final String id;
  double comprUnit;
  double comprCorte;
  int qtde;

  PosicaoMedidaCreateModel({
    this.comprUnit = 0,
    this.comprCorte = 0,
    this.qtde = 1,
  }) : id = HashService.get;

  PosicaoMedidaCreateModel.fromModel(PosicaoMedidaModel m)
      : id = m.id,
        comprUnit = m.comprUnit,
        comprCorte = m.comprCorte,
        qtde = m.qtde;
}

class ElementoPosicaoCreateModel {
  final String id;
  final TextController nome = TextController();
  final TextController numeroOs = TextController();
  final TextController pesoKg = TextController();
  final TextController qtde = TextController(text: '0');
  final TextController comprUnit = TextController(text: '0');
  final TextController comprCorte = TextController(text: '0');
  BitolaModel? produto;
  bool isEdit;
  List<PosicaoMedidaCreateModel> medidas = [];

  ElementoPosicaoCreateModel({this.isEdit = false}) : id = HashService.get;

  ElementoPosicaoCreateModel.fromModel(ElementoPosicaoModel m)
      : id = m.id,
        produto = m.produto,
        isEdit = true {
    nome.text = m.nome;
    numeroOs.text = m.numeroOs;
    pesoKg.text = m.pesoKg.toStringAsFixed(3);
    qtde.text = m.qtde.toString();
    comprUnit.text = m.comprUnit.toStringAsFixed(3);
    comprCorte.text = m.comprCorte.toStringAsFixed(3);
    medidas = m.medidas.map((m) => PosicaoMedidaCreateModel.fromModel(m)).toList();
  }

  /// Se esta posição tem comprimentos variáveis
  bool get isVariavel => medidas.isNotEmpty;

  bool get isValid =>
      nome.text.isNotEmpty &&
      numeroOs.text.isNotEmpty &&
      produto != null &&
      pesoDouble > 0;

  double get pesoDouble =>
      double.tryParse(pesoKg.text.replaceAll(',', '.')) ?? 0.0;
  int get qtdeInt => int.tryParse(qtde.text) ?? 0;
  double get comprUnitDouble =>
      double.tryParse(comprUnit.text.replaceAll(',', '.')) ?? 0.0;
  double get comprCorteDouble =>
      double.tryParse(comprCorte.text.replaceAll(',', '.')) ?? 0.0;

  ElementoPosicaoModel toModel(String elementoId) => ElementoPosicaoModel(
        id: id,
        elementoId: elementoId,
        nome: nome.text,
        numeroOs: numeroOs.text,
        produtoId: produto!.id,
        produto: produto,
        pesoKg: pesoDouble,
        qtde: qtdeInt,
        comprUnit: comprUnitDouble,
        comprCorte: comprCorteDouble,
        createdAt: DateTime.now(),
        medidas: medidas.map((m) => PosicaoMedidaModel(
          id: m.id,
          posicaoId: id,
          comprUnit: m.comprUnit,
          comprCorte: m.comprCorte,
          qtde: m.qtde,
        )).toList(),
      );
}

class ElementoCreateModel {
  final String id;
  final TextController nome = TextController();
  final TextController qtde = TextController(text: '1');
  List<ElementoPosicaoCreateModel> posicoes = [];
  bool isEdit;

  ElementoCreateModel({this.isEdit = false}) : id = HashService.get;

  ElementoCreateModel.fromModel(ElementoModel m)
      : id = m.id,
        isEdit = true {
    nome.text = m.nome;
    qtde.text = m.qtde.toString();
    posicoes =
        m.posicoes.map((p) => ElementoPosicaoCreateModel.fromModel(p)).toList();
  }

  int get qtdeInt => int.tryParse(qtde.text) ?? 1;

  double get pesoTotal =>
      posicoes.fold(0.0, (sum, p) => sum + p.pesoDouble) * qtdeInt;

  bool get isValid =>
      (nome.text.isNotEmpty || isEdit) && posicoes.isNotEmpty && qtdeInt > 0;
}
