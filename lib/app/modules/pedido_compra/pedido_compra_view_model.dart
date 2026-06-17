import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
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
