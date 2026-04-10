import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/modules/elemento/elemento_arquivo_model.dart';
import 'package:flutter/material.dart';

// ─── STATUS DO ELEMENTO ───────────────────────────────────────────────────────
enum ElementoStatus {
  aguardando,
  armando,
  pronto;

  String get label {
    switch (this) {
      case ElementoStatus.aguardando: return 'Aguardando';
      case ElementoStatus.armando: return 'Armando';
      case ElementoStatus.pronto: return 'Pronto';
    }
  }

  Color get color {
    switch (this) {
      case ElementoStatus.aguardando: return Colors.grey[400]!;
      case ElementoStatus.armando: return Colors.yellow[700]!;
      case ElementoStatus.pronto: return Colors.green[600]!;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ElementoStatus.aguardando: return Colors.grey[100]!;
      case ElementoStatus.armando: return Colors.yellow[50]!;
      case ElementoStatus.pronto: return Colors.green[50]!;
    }
  }
}

// ─── POSIÇÃO / OS ─────────────────────────────────────────────────────────────
class ElementoPosicaoModel {
  final String id;
  final String elementoId;
  final String nome;       // nome da posição (ex: "Pilar P1")
  final String numeroOs;   // número da OS (ex: "OS 1", "001")
  final String produtoId;
  ProdutoModel? produto;   // bitola do catálogo
  final double pesoKg;
  final DateTime createdAt;

  ElementoPosicaoModel({
    required this.id,
    required this.elementoId,
    required this.nome,
    required this.numeroOs,
    required this.produtoId,
    required this.pesoKg,
    required this.createdAt,
    this.produto,
  });

  factory ElementoPosicaoModel.fromSupabaseMap(Map<String, dynamic> map) {
    final produtoId = (map['produto_id'] ?? '').toString();
    return ElementoPosicaoModel(
      id: (map['id'] ?? '').toString(),
      elementoId: (map['elemento_id'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      numeroOs: (map['numero_os'] ?? '').toString(),
      produtoId: produtoId,
      pesoKg: double.tryParse((map['peso_kg'] ?? '0').toString()) ?? 0.0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      produto: FirestoreClient.produtos.data
          .where((p) => p.id == produtoId)
          .firstOrNull,
    );
  }

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'elemento_id': elementoId,
        'nome': nome,
        'numero_os': numeroOs,
        'produto_id': produtoId,
        'peso_kg': pesoKg,
      };
}

// ─── ELEMENTO ─────────────────────────────────────────────────────────────────
class ElementoModel {
  final String id;
  final String pedidoId;
  final String nome;
  final int qtde;
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
    this.status = ElementoStatus.aguardando,
  });

  /// Peso total calculado (soma das posições * qtde)
  double get pesoTotal =>
      posicoes.fold(0.0, (sum, p) => sum + p.pesoKg) * qtde;

  /// Peso unitário de um elemento (soma das posições)
  double get pesoUnitario =>
      posicoes.fold(0.0, (sum, p) => sum + p.pesoKg);


  /// Peso agrupado por produto (bitola)
  Map<String, double> get pesoPorBitola {
    final map = <String, double>{};
    for (final p in posicoes) {
      map[p.produtoId] = (map[p.produtoId] ?? 0.0) + p.pesoKg;
    }
    return map;
  }

  factory ElementoModel.fromSupabaseMap(
    Map<String, dynamic> map, {
    List<Map<String, dynamic>>? posicoesRaw,
    List<Map<String, dynamic>>? arquivosRaw,
  }) {
    final posicoes = (posicoesRaw ?? [])
        .map((p) => ElementoPosicaoModel.fromSupabaseMap(p))
        .toList();
    final arquivos = (arquivosRaw ?? [])
        .map((a) => ElementoArquivoModel.fromMap(a))
        .toList();
    return ElementoModel(
      id: (map['id'] ?? '').toString(),
      pedidoId: (map['pedido_id'] ?? '').toString(),
      nome: (map['nome'] ?? '').toString(),
      qtde: int.tryParse((map['qtde'] ?? '1').toString()) ?? 1,
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
        'status': status.name,
      };
}

// ─── MODELOS DE CRIAÇÃO / EDIÇÃO (para formulário) ───────────────────────────

class ElementoPosicaoCreateModel {
  final String id;
  final TextController nome = TextController();
  final TextController numeroOs = TextController();
  final TextController pesoKg = TextController();
  ProdutoModel? produto;
  bool isEdit;

  ElementoPosicaoCreateModel({this.isEdit = false}) : id = HashService.get;

  ElementoPosicaoCreateModel.fromModel(ElementoPosicaoModel m)
      : id = m.id,
        produto = m.produto,
        isEdit = true {
    nome.text = m.nome;
    numeroOs.text = m.numeroOs;
    pesoKg.text = m.pesoKg.toStringAsFixed(3);
  }

  bool get isValid =>
      nome.text.isNotEmpty && numeroOs.text.isNotEmpty && produto != null && pesoDouble > 0;

  double get pesoDouble => double.tryParse(pesoKg.text.replaceAll(',', '.')) ?? 0.0;

  ElementoPosicaoModel toModel(String elementoId) => ElementoPosicaoModel(
        id: id,
        elementoId: elementoId,
        nome: nome.text,
        numeroOs: numeroOs.text,
        produtoId: produto!.id,
        produto: produto,
        pesoKg: pesoDouble,
        createdAt: DateTime.now(),
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
    posicoes = m.posicoes
        .map((p) => ElementoPosicaoCreateModel.fromModel(p))
        .toList();
  }

  int get qtdeInt => int.tryParse(qtde.text) ?? 1;

  double get pesoTotal =>
      posicoes.fold(0.0, (sum, p) => sum + p.pesoDouble) * qtdeInt;

  bool get isValid => (nome.text.isNotEmpty || isEdit) && posicoes.isNotEmpty && qtdeInt > 0;
}
