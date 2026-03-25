class PedidoArquivoModel {
  final String id;
  final String? pedidoId;
  final String nome;
  final String url;
  final int tamanho;
  final String tipo;
  final String extensao;
  final DateTime criadoEm;
  final bool isProcessed;

  PedidoArquivoModel({
    required this.id,
    this.pedidoId,
    required this.nome,
    required this.url,
    required this.tamanho,
    required this.tipo,
    required this.extensao,
    required this.criadoEm,
    required this.isProcessed,
  });

  factory PedidoArquivoModel.fromMap(Map<String, dynamic> map) {
    return PedidoArquivoModel(
      id: map['id'] ?? '',
      pedidoId: map['pedido_id'],
      nome: map['nome'] ?? '',
      url: map['url'] ?? '',
      tamanho: map['tamanho'] ?? 0,
      tipo: map['tipo'] ?? '',
      extensao: map['extensao'] ?? '',
      criadoEm: map['criado_em'] != null
          ? DateTime.parse(map['criado_em'])
          : DateTime.now(),
      isProcessed: map['is_processed'] ?? false,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id.isEmpty ? null : id,
      'pedido_id': pedidoId,
      'nome': nome,
      'url': url,
      'tamanho': tamanho,
      'tipo': tipo,
      'extensao': extensao,
      'is_processed': isProcessed,
    };
  }
}
