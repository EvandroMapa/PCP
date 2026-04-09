import 'dart:convert';

class ElementoArquivoModel {
  final String id;
  final String elementoId;
  final String nome;
  final String url;
  final int tamanho;
  final String tipo;
  final String extensao;
  final DateTime criadoEm;

  ElementoArquivoModel({
    required this.id,
    required this.elementoId,
    required this.nome,
    required this.url,
    required this.tamanho,
    required this.tipo,
    required this.extensao,
    required this.criadoEm,
  });

  factory ElementoArquivoModel.fromMap(Map<String, dynamic> map) {
    return ElementoArquivoModel(
      id: map['id'] ?? '',
      elementoId: map['elemento_id'] ?? '',
      nome: map['nome'] ?? '',
      url: map['url'] ?? '',
      tamanho: map['tamanho'] ?? 0,
      tipo: map['tipo'] ?? '',
      extensao: map['extensao'] ?? '',
      criadoEm: map['criado_em'] != null
          ? DateTime.tryParse(map['criado_em'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'elemento_id': elementoId,
      'nome': nome,
      'url': url,
      'tamanho': tamanho,
      'tipo': tipo,
      'extensao': extensao,
    };
  }
}
