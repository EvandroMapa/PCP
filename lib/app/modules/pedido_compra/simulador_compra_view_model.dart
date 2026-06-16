import 'dart:math';

import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';

/// Item individual do simulador de compra
class SimuladorCompraItem {
  final BitolaModel produto;
  final double saldoFisico;
  final double consumoPrevisto;
  final double emPedido;
  final double estoqueMinimo;
  final double estoqueIdeal;
  final TextController quantidadeSugerida = TextController();
  bool incluir;

  /// Sugestão base (déficit arredondado pelo múltiplo padrão, read-only)
  double sugestaoBase = 0;

  SimuladorCompraItem({
    required this.produto,
    required this.saldoFisico,
    required this.consumoPrevisto,
    required this.emPedido,
    required this.estoqueMinimo,
    required this.estoqueIdeal,
    required double sugestaoInicial,
    required this.incluir,
  }) {
    sugestaoBase = sugestaoInicial;
    quantidadeSugerida.text =
        sugestaoInicial > 0 ? sugestaoInicial.toStringAsFixed(0) : '';
  }

  /// Nível alvo para sugestão: usa estoqueIdeal se > 0, senão estoqueMinimo
  double get nivelAlvo => estoqueIdeal > 0 ? estoqueIdeal : estoqueMinimo;

  /// Saldo projetado sem compra = Saldo - Consumo + Em Pedido
  double get saldoProjetado => saldoFisico - consumoPrevisto + emPedido;

  /// Necessidade = max(0, Consumo + NivelAlvo - Saldo - EmPedido)
  double get necessidade =>
      max(0.0, consumoPrevisto + nivelAlvo - saldoFisico - emPedido);

  /// Quantidade digitada pelo usuário
  double get quantidadeDigitada =>
      double.tryParse(
          quantidadeSugerida.text.replaceAll(',', '.')) ??
      0.0;

  /// Saldo projetado APÓS a compra sugerida
  double get saldoProjetadoComCompra => saldoProjetado + quantidadeDigitada;

  /// Tem déficit (projetado sem compra < nível alvo)
  bool get temDeficit => saldoProjetado < nivelAlvo;
}

/// Model principal do simulador
class SimuladorCompraModel {
  List<SimuladorCompraItem> itens;

  /// Configuração de formatação de carga
  bool formatarCarga = false;
  final TextController pesoAlvoCarga = TextController(text: '30000');
  final TextController multiploArredondamento = TextController(text: '1000');

  SimuladorCompraModel({required this.itens});

  /// Peso-alvo em kg
  double get pesoAlvoValue =>
      double.tryParse(pesoAlvoCarga.text.replaceAll(',', '.')) ?? 0.0;

  /// Múltiplo de arredondamento em kg
  double get multiploValue =>
      double.tryParse(multiploArredondamento.text.replaceAll(',', '.')) ?? 0.0;

  /// Delta entre total sugerido e peso-alvo
  double get deltaCarga => totalSugerido - pesoAlvoValue;

  /// Itens marcados para inclusão no pedido
  List<SimuladorCompraItem> get itensSelecionados =>
      itens.where((i) => i.incluir && i.quantidadeDigitada > 0).toList();

  /// Total de kg sugerido (todos os selecionados)
  double get totalSugerido =>
      itensSelecionados.fold(0.0, (s, i) => s + i.quantidadeDigitada);

  /// Total sugestão base (antes do ajuste de carga)
  double get totalSugestaoBase =>
      itens.fold(0.0, (s, i) => s + i.sugestaoBase);

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

  /// Percentual atual do pedido em relação à sugestão base (0.0 a 2.0+)
  double get percentualAtual =>
      totalSugestaoBase > 0 ? (totalSugerido / totalSugestaoBase).clamp(0.0, 2.0) : 1.0;
}
