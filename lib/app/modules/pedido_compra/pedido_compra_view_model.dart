import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';

/// Item individual do carrinho de criação
class PedidoCompraItemForm {
  ProdutoModel? produto;
  final TextController quantidade = TextController();

  bool get isValid => produto != null && quantidadeValue > 0;

  double get quantidadeValue =>
      double.tryParse(quantidade.text.replaceAll(',', '.')) ?? 0.0;
}

/// Form principal: 1 fabricante + N itens
class PedidoCompraCreateModel {
  String? grupoId;
  FabricanteModel? fabricante;
  List<PedidoCompraItemForm> itens = [];

  bool get modoEdicao => grupoId != null;
  bool get fabricanteValido => fabricante != null;
  bool get isValid =>
      fabricante != null && itens.any((i) => i.isValid);

  List<PedidoCompraItemForm> get itensValidos =>
      itens.where((i) => i.isValid).toList();

  void adicionarItem() => itens.add(PedidoCompraItemForm());

  void removerItem(PedidoCompraItemForm item) => itens.remove(item);

  void clear() {
    grupoId = null;
    fabricante = null;
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
