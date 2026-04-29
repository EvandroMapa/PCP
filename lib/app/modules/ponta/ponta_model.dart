import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';

/// Modelo de uma ponta (sobra de barra) salva no Supabase.
class PontaModel {
  final String id;
  final String bitolaId;
  final String bitolaDescricao;
  double tamanho;
  int quantidade;
  String localizador;
  final String? planoCorteId;
  final String? ordemId;
  final DateTime createdAt;
  DateTime updatedAt;

  PontaModel({
    required this.id,
    required this.bitolaId,
    required this.bitolaDescricao,
    required this.tamanho,
    required this.quantidade,
    this.localizador = '',
    this.planoCorteId,
    this.ordemId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PontaModel.fromSupabaseMap(Map<String, dynamic> map) {
    return PontaModel(
      id: map['id'] ?? '',
      bitolaId: map['bitola_id'] ?? '',
      bitolaDescricao: map['bitola_descricao'] ?? '',
      tamanho: (map['tamanho'] ?? 0).toDouble(),
      quantidade: map['quantidade'] ?? 1,
      localizador: map['localizador'] ?? '',
      planoCorteId: map['plano_corte_id']?.toString(),
      ordemId: map['ordem_id']?.toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'bitola_id': bitolaId,
        'bitola_descricao': bitolaDescricao,
        'tamanho': tamanho,
        'quantidade': quantidade,
        'localizador': localizador,
        if (planoCorteId != null) 'plano_corte_id': planoCorteId,
        if (ordemId != null) 'ordem_id': ordemId,
      };

  Map<String, dynamic> toUpdateMap() => {
        'tamanho': tamanho,
        'quantidade': quantidade,
        'localizador': localizador,
        'updated_at': DateTime.now().toIso8601String(),
      };
}

/// Agrupamento de pontas por bitola para exibição.
class PontaBitolaGrupo {
  final String bitolaId;
  final String bitolaDescricao;
  final List<PontaModel> pontas;

  // Estado da ordenação para este grupo (padrão decrescente por comprimento)
  String sortColumn = 'tamanho';
  bool sortAscending = false;

  PontaBitolaGrupo({
    required this.bitolaId,
    required this.bitolaDescricao,
    required this.pontas,
  }) {
    sort();
  }

  void sort() {
    pontas.sort((a, b) {
      int result = 0;
      switch (sortColumn) {
        case 'tamanho':
          result = a.tamanho.compareTo(b.tamanho);
          break;
        case 'quantidade':
          result = a.quantidade.compareTo(b.quantidade);
          break;
        case 'localizador':
          result = a.localizador.compareTo(b.localizador);
          break;
      }
      return sortAscending ? result : -result;
    });
  }

  double get totalTamanho =>
      pontas.fold(0.0, (s, p) => s + (p.tamanho * p.quantidade));
  
  int get totalPecas => pontas.fold(0, (s, p) => s + p.quantidade);

  double get totalPeso {
    try {
      // Busca o produto (bitola) para pegar a massa/kg por metro
      final produto =
          FirestoreClient.produtos.data.firstWhere((p) => p.id == bitolaId);
      // Tamanho é informado em centímetros, então dividimos por 100 para metros
      return (totalTamanho / 100) * produto.massaFinal;
    } catch (_) {
      return 0.0;
    }
  }
}
