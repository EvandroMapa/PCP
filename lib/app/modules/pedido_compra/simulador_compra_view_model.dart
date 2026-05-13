import 'dart:math';

import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';

/// Item individual do simulador de compra
class SimuladorCompraItem {
  final ProdutoModel produto;
  final double saldoFisico;
  final double consumoPrevisto;
  final double emPedido;
  final double estoqueMinimo;
  final TextController quantidadeSugerida = TextController();
  bool incluir;

  SimuladorCompraItem({
    required this.produto,
    required this.saldoFisico,
    required this.consumoPrevisto,
    required this.emPedido,
    required this.estoqueMinimo,
    required double sugestaoInicial,
    required this.incluir,
  }) {
    quantidadeSugerida.text =
        sugestaoInicial > 0 ? sugestaoInicial.toStringAsFixed(3) : '';
  }

  /// Saldo projetado sem compra = Saldo - Consumo + Em Pedido
  double get saldoProjetado => saldoFisico - consumoPrevisto + emPedido;

  /// Necessidade = max(0, Consumo + EstoqueMinimo - Saldo - EmPedido)
  double get necessidade =>
      max(0.0, consumoPrevisto + estoqueMinimo - saldoFisico - emPedido);

  /// Quantidade digitada pelo usuário
  double get quantidadeDigitada =>
      double.tryParse(
          quantidadeSugerida.text.replaceAll(',', '.')) ??
      0.0;

  /// Saldo projetado APÓS a compra sugerida
  double get saldoProjetadoComCompra => saldoProjetado + quantidadeDigitada;

  /// Tem déficit (projetado sem compra < estoque mínimo)
  bool get temDeficit => saldoProjetado < estoqueMinimo;
}

/// Model principal do simulador
class SimuladorCompraModel {
  List<SimuladorCompraItem> itens;

  SimuladorCompraModel({required this.itens});

  /// Itens marcados para inclusão no pedido
  List<SimuladorCompraItem> get itensSelecionados =>
      itens.where((i) => i.incluir && i.quantidadeDigitada > 0).toList();

  /// Total de kg sugerido
  double get totalSugerido =>
      itensSelecionados.fold(0.0, (s, i) => s + i.quantidadeDigitada);

  /// Quantidade de itens com déficit
  int get totalComDeficit => itens.where((i) => i.temDeficit).length;

  /// Total saldo físico
  double get totalSaldoFisico =>
      itens.fold(0.0, (s, i) => s + i.saldoFisico);

  /// Total consumo previsto
  double get totalConsumoPrevisto =>
      itens.fold(0.0, (s, i) => s + i.consumoPrevisto);

  /// Total em pedido
  double get totalEmPedido =>
      itens.fold(0.0, (s, i) => s + i.emPedido);

  /// Total projetado sem compra
  double get totalProjetado =>
      itens.fold(0.0, (s, i) => s + i.saldoProjetado);

  /// Total projetado com compra
  double get totalProjetadoComCompra =>
      itens.fold(0.0, (s, i) => s + i.saldoProjetadoComCompra);
}
