import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';

/// Item individual do carrinho de criação
class PedidoCompraItemForm {
  BitolaModel? produto;
  final TextController quantidade = TextController();

  bool get isValid => produto != null && quantidadeValue > 0;

  double get quantidadeValue =>
      double.tryParse(quantidade.text.replaceAll(',', '.')) ?? 0.0;
}

/// Form principal: N itens (fabricante é escolhido na confirmação)
class PedidoCompraCreateModel {
  String? grupoId;
  List<PedidoCompraItemForm> itens = [];

  bool get modoEdicao => grupoId != null;
  bool get isValid => itens.any((i) => i.isValid);

  List<PedidoCompraItemForm> get itensValidos =>
      itens.where((i) => i.isValid).toList();

  void adicionarItem() => itens.add(PedidoCompraItemForm());

  void removerItem(PedidoCompraItemForm item) => itens.remove(item);

  void clear() {
    grupoId = null;
    itens = [];
  }
}

/// Form de conversão de um grupo de itens
class PedidoCompraConverterGrupoModel {
  final List<PedidoCompraModel> itens;
  final List<TextController> quantidadesRecebidas;
  final TextController observacao = TextController();

  PedidoCompraConverterGrupoModel(this.itens)
      : quantidadesRecebidas = itens
            .map((i) => TextController(
                  text: i.quantidade.toStringAsFixed(3),
                ))
            .toList();

  bool get isValid =>
      quantidadesRecebidas.every((q) => _parseQtde(q.text) > 0);

  double getQuantidadeRecebida(int index) =>
      _parseQtde(quantidadesRecebidas[index].text);

  double _parseQtde(String text) =>
      double.tryParse(text.replaceAll(',', '.')) ?? 0.0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Planilha Multi-Fornecedor
// ─────────────────────────────────────────────────────────────────────────────

/// Item de uma linha da planilha (uma bitola)
class PedidoCompraPlanilhaItem {
  final BitolaModel produto;
  final double saldoFisico;
  final double consumoPrevisto;
  bool incluir;

  /// Um TextController por slot de fornecedor (sempre 3, usados conforme colunas ativas)
  final List<TextController> quantidades = [
    TextController(),
    TextController(),
    TextController(),
  ];

  PedidoCompraPlanilhaItem({
    required this.produto,
    required this.saldoFisico,
    required this.consumoPrevisto,
    this.incluir = false,
  });

  double getQuantidade(int idx) =>
      double.tryParse(quantidades[idx].text.replaceAll(',', '.')) ?? 0.0;

  /// Soma das quantidades de todos os fornecedores para este item
  double totalPedido(int numeroColunas) {
    double soma = 0;
    for (int i = 0; i < numeroColunas; i++) {
      soma += getQuantidade(i);
    }
    return soma;
  }

  /// Saldo projetado consolidado = Saldo - Consumo + soma de todos os fornecedores
  double saldoProjetado(int numeroColunas) =>
      saldoFisico - consumoPrevisto + totalPedido(numeroColunas);

  bool get temDeficit => saldoFisico < consumoPrevisto;
}

/// Model principal da planilha multi-fornecedor
class PedidoCompraPlanilhaModel {
  List<PedidoCompraPlanilhaItem> itens;

  /// Até 3 fornecedores (null = slot não selecionado)
  final List<FabricanteModel?> fornecedores = [null, null, null];

  /// Quantas colunas de fornecedor estão visíveis (1 a 3)
  int colunas = 1;

  PedidoCompraPlanilhaModel({required this.itens});

  /// Fornecedores nas colunas visíveis
  List<FabricanteModel?> get fornecedoresVisiveis =>
      fornecedores.sublist(0, colunas);

  /// Itens marcados com ao menos 1 quantidade > 0 no fornecedor [idx]
  List<PedidoCompraPlanilhaItem> itensPorFornecedor(int idx) =>
      itens.where((i) => i.incluir && i.getQuantidade(idx) > 0).toList();

  /// Grupos prontos para salvar: (fabricante, itens) — apenas colunas com fornecedor e itens válidos
  List<({FabricanteModel fabricante, List<PedidoCompraPlanilhaItem> itens, int colunaIdx})>
      get gruposParaSalvar {
    final resultado = <({FabricanteModel fabricante, List<PedidoCompraPlanilhaItem> itens, int colunaIdx})>[];
    for (int i = 0; i < colunas; i++) {
      final fab = fornecedores[i];
      if (fab == null) continue;
      final itensDoFornecedor = itensPorFornecedor(i);
      if (itensDoFornecedor.isNotEmpty) {
        resultado.add((fabricante: fab, itens: itensDoFornecedor, colunaIdx: i));
      }
    }
    return resultado;
  }

  bool get podeSerSalvo => gruposParaSalvar.isNotEmpty;

  // ── Totais por coluna ──────────────────────────────────────────────────────

  double totalSaldo() =>
      itens.fold(0.0, (s, i) => s + i.saldoFisico);

  double totalConsumo() =>
      itens.fold(0.0, (s, i) => s + i.consumoPrevisto);

  double totalPedidoPorFornecedor(int idx) =>
      itens.fold(0.0, (s, i) => s + (i.incluir ? i.getQuantidade(idx) : 0.0));

  double totalProjetado() =>
      itens.fold(0.0, (s, i) => s + i.saldoProjetado(colunas));

  int get totalComDeficit => itens.where((i) => i.temDeficit).length;

  int get totalMarcados => itens.where((i) => i.incluir).length;
}
