import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';

final armacaoCtrl = ArmacaoController();

class ArmacaoController {
  static final ArmacaoController _instance = ArmacaoController._();
  ArmacaoController._();
  factory ArmacaoController() => _instance;

  final TextController search = TextController();
  final AppStream<List<PedidoModel>> pedidosStream = AppStream.seed([]);

  void onInit() {
    FirestoreClient.pedidos.dataStream.listen.listen((pedidos) {
      _filterPedidos(pedidos);
    });
    FirestoreClient.steps.dataStream.listen.listen((_) {
      _filterPedidos(FirestoreClient.pedidos.data);
    });
  }

  void _filterPedidos(List<PedidoModel> all) {
    final filtered = all.where((p) {
      final isVisible = p.step.isExibirArmacao;
      final matchesSearch = p.localizador.toLowerCase().contains(search.text.toLowerCase()) ||
          p.cliente.nome.toLowerCase().contains(search.text.toLowerCase());
      return isVisible && matchesSearch;
    }).toList();
    
    // Ordenar por data de entrega ou criação
    filtered.sort((a, b) => (a.deliveryAt ?? a.createdAt).compareTo(b.deliveryAt ?? b.createdAt));
    
    pedidosStream.add(filtered);
  }

  void onSearch(String val) {
    _filterPedidos(FirestoreClient.pedidos.data);
  }
}
