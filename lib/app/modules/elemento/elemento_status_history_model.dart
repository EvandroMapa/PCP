import 'package:aco_plus/app/modules/elemento/elemento_model.dart';

class ElementoStatusHistoryModel {
  final String id;
  final String elementoId;
  final String pedidoId;
  final ElementoStatus status;
  final int qtdePronto;
  final DateTime createdAt;

  ElementoStatusHistoryModel({
    required this.id,
    required this.elementoId,
    required this.pedidoId,
    required this.status,
    required this.qtdePronto,
    required this.createdAt,
  });

  factory ElementoStatusHistoryModel.fromSupabaseMap(
      Map<String, dynamic> map) {
    return ElementoStatusHistoryModel(
      id: (map['id'] ?? '').toString(),
      elementoId: (map['elemento_id'] ?? '').toString(),
      pedidoId: (map['pedido_id'] ?? '').toString(),
      status: ElementoStatus.values.firstWhere(
          (e) => e.name == (map['status'] ?? 'aguardando'),
          orElse: () => ElementoStatus.aguardando),
      qtdePronto: int.tryParse((map['qtde_pronto'] ?? '0').toString()) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
