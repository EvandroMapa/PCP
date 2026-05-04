class PedidoBoxModel {
  final String id;
  final String pedidoId;
  final String boxId;
  final DateTime createdAt;

  PedidoBoxModel({
    required this.id,
    required this.pedidoId,
    required this.boxId,
    required this.createdAt,
  });

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'pedido_id': pedidoId,
        'box_id': boxId,
        'created_at': createdAt.toIso8601String(),
      };

  factory PedidoBoxModel.fromSupabaseMap(Map<String, dynamic> map) =>
      PedidoBoxModel(
        id: map['id'] ?? '',
        pedidoId: map['pedido_id'] ?? '',
        boxId: map['box_id'] ?? '',
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'])
            : DateTime.now(),
      );
}
