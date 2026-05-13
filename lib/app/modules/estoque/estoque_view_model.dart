import 'package:aco_plus/app/core/models/text_controller.dart';

class EstoqueUtils {
  final TextController search = TextController();
}

class EstoqueCompraCreateModel {
  String? produtoId;
  final TextController quantidade = TextController();
  final TextController observacao = TextController();
  DateTime dataCompra = DateTime.now();

  bool get isValid =>
      produtoId != null &&
      double.tryParse(quantidade.text.replaceAll(',', '.')) != null;

  double get quantidadeValue =>
      double.tryParse(quantidade.text.replaceAll(',', '.')) ?? 0.0;

  void clear() {
    produtoId = null;
    quantidade.controller.clear();
    observacao.controller.clear();
    dataCompra = DateTime.now();
  }
}

class EstoqueEditarSaldoModel {
  final String produtoId;
  final TextController novoSaldo = TextController();
  final TextController estoqueMinimo = TextController();

  EstoqueEditarSaldoModel({
    required this.produtoId,
    double saldoAtual = 0,
    double estoqueMinimoAtual = 0,
  }) {
    novoSaldo.text = saldoAtual == 0
        ? ''
        : saldoAtual.toStringAsFixed(3).replaceAll('.000', '');
    estoqueMinimo.text = estoqueMinimoAtual == 0
        ? ''
        : estoqueMinimoAtual.toStringAsFixed(3).replaceAll('.000', '');
  }

  double get novoSaldoValue =>
      double.tryParse(novoSaldo.text.replaceAll(',', '.')) ?? 0.0;

  double get estoqueMinimoValue =>
      double.tryParse(estoqueMinimo.text.replaceAll(',', '.')) ?? 0.0;
}

class EstoqueRelatorioFiltroModel {
  DateTime? dataInicio;
  DateTime? dataFim;
  String? produtoId;

  bool get temFiltro =>
      dataInicio != null || dataFim != null || produtoId != null;

  void limpar() {
    dataInicio = null;
    dataFim = null;
    produtoId = null;
  }
}
