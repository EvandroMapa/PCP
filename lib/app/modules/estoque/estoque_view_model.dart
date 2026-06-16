import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_movimentacao_model.dart';
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
  final TextController estoqueMinimo = TextController();
  final TextController estoqueIdeal = TextController();

  EstoqueEditarSaldoModel({
    required this.produtoId,
    double estoqueMinimoAtual = 0,
    double estoqueIdealAtual = 0,
  }) {
    estoqueMinimo.text = estoqueMinimoAtual == 0
        ? ''
        : estoqueMinimoAtual.toStringAsFixed(3).replaceAll('.000', '');
    estoqueIdeal.text = estoqueIdealAtual == 0
        ? ''
        : estoqueIdealAtual.toStringAsFixed(3).replaceAll('.000', '');
  }

  double get estoqueMinimoValue =>
      double.tryParse(estoqueMinimo.text.replaceAll(',', '.')) ?? 0.0;

  double get estoqueIdealValue =>
      double.tryParse(estoqueIdeal.text.replaceAll(',', '.')) ?? 0.0;
}

/// Model para o novo dialog de ajuste de saldo por movimentação.
class EstoqueAjusteModel {
  final String produtoId;
  final double saldoAtual;
  EstoqueTipoMovimentacao tipo;
  final TextController quantidade = TextController();
  final TextController saldoFinal = TextController();
  final TextController motivo = TextController();

  /// Controla qual campo foi editado por último para evitar loop de atualização.
  bool _editandoSaldoFinal = false;

  EstoqueAjusteModel({
    required this.produtoId,
    required this.saldoAtual,
    this.tipo = EstoqueTipoMovimentacao.ajusteEntrada,
  });

  double get quantidadeValue =>
      double.tryParse(quantidade.text.replaceAll(',', '.')) ?? 0.0;

  double get saldoFinalValue =>
      double.tryParse(saldoFinal.text.replaceAll(',', '.')) ?? saldoAtual;

  bool get isEntrada => tipo == EstoqueTipoMovimentacao.ajusteEntrada;

  double get saldoResultante =>
      saldoAtual + (isEntrada ? quantidadeValue : -quantidadeValue);

  bool get isValid =>
      quantidadeValue > 0 && motivo.text.trim().isNotEmpty;

  /// Chamado quando o usuário digita na Quantidade.
  /// Recalcula e atualiza o Saldo Final exibido.
  void onQuantidadeChanged(void Function(void Function()) setState) {
    if (_editandoSaldoFinal) return;
    setState(() {
      final qtde = quantidadeValue;
      if (qtde > 0) {
        final resultado = saldoAtual + (isEntrada ? qtde : -qtde);
        saldoFinal.text = resultado == 0
            ? ''
            : resultado.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
      } else {
        saldoFinal.text = '';
      }
    });
  }

  /// Chamado quando o usuário digita no Saldo Final.
  /// Calcula a diferença, determina se é entrada ou saída,
  /// e atualiza o campo Quantidade automaticamente.
  void onSaldoFinalChanged(void Function(void Function()) setState) {
    _editandoSaldoFinal = true;
    setState(() {
      final meta = saldoFinalValue;
      final diff = meta - saldoAtual;
      if (diff == 0) {
        quantidade.text = '';
      } else if (diff > 0) {
        tipo = EstoqueTipoMovimentacao.ajusteEntrada;
        quantidade.text = diff.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
      } else {
        tipo = EstoqueTipoMovimentacao.ajusteSaida;
        quantidade.text = (-diff).toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
      }
    });
    _editandoSaldoFinal = false;
  }
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

/// Filtro para a seção de Movimentação de Estoque (multi-bitola + período)
class EstoqueMovimentacaoFiltroModel {
  /// IDs dos produtos (bitolas) selecionados. Lista vazia = nenhum filtrado.
  List<String> produtoIds = [];

  /// Padrão: primeiro dia do mês corrente
  DateTime dataInicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? dataFim;

  bool get temFiltro =>
      produtoIds.isNotEmpty || dataFim != null;

  void limpar() {
    produtoIds.clear();
    dataInicio = DateTime(DateTime.now().year, DateTime.now().month, 1);
    dataFim = null;
  }

  bool contemProduto(String id) => produtoIds.contains(id);

  void toggleProduto(String id) {
    if (produtoIds.contains(id)) {
      produtoIds.remove(id);
    } else {
      produtoIds.add(id);
    }
  }
}

/// Linha de movimentação com saldo acumulado — usada na seção de extrato
class EstoqueLinhaMovimentacao {
  final String produtoId;
  final DateTime dataHora;
  final String tipoLabel;
  final String tipoValue;
  final double quantidade;
  final double saldoAcumulado;
  final String? observacao;
  final String? ordemId;
  final String? usuarioNome;

  /// true = entrada (compra, implantação, estorno positivo)
  /// false = saída (baixa produção, estorno negativo)
  final bool isEntrada;

  const EstoqueLinhaMovimentacao({
    required this.produtoId,
    required this.dataHora,
    required this.tipoLabel,
    required this.tipoValue,
    required this.quantidade,
    required this.saldoAcumulado,
    this.observacao,
    this.ordemId,
    this.usuarioNome,
    required this.isEntrada,
  });
}
