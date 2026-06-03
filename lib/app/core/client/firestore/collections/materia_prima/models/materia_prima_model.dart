import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/enums/materia_prima_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/components/archive/archive_model.dart';

class MateriaPrimaModel {
  final String id;
  final FabricanteModel fabricanteModel;
  final BitolaModel produto;
  final String corridaLote;
  final List<ArchiveModel> anexos;
  MateriaPrimaStatus status;

  MateriaPrimaModel({
    required this.id,
    required this.fabricanteModel,
    required this.produto,
    required this.corridaLote,
    required this.anexos,
    required this.status,
  });

  String get label => '${fabricanteModel.nome} - $corridaLote';

  static MateriaPrimaModel empty() => MateriaPrimaModel(
        id: 'register_unavailable',
        fabricanteModel: FabricanteModel.empty(),
        produto: BitolaModel.empty(),
        corridaLote: 'Não especificado',
        anexos: [],
        status: MateriaPrimaStatus.disponivel,
      );

  factory MateriaPrimaModel.fromMap(Map<String, dynamic> map) {
    final fabricanteSnapshot = FabricanteModel.fromMap(map['fabricanteModel']);
    final produtoSnapshot = BitolaModel.fromMap(map['produto']);
    // Dynamic linking: busca versão mais recente no cache reativo
    final fabricante = BackendClient.fabricantes.data.isNotEmpty
        ? BackendClient.fabricantes.getById(fabricanteSnapshot.id)
        : fabricanteSnapshot;
    final produto = BackendClient.bitolas.data.isNotEmpty
        ? BackendClient.bitolas.getById(produtoSnapshot.id)
        : produtoSnapshot;
    return MateriaPrimaModel(
      id: map['id'] as String,
      fabricanteModel: fabricante,
      produto: produto,
      corridaLote: map['corridaLote'] as String,
      anexos: map['anexos'] != null
          ? (map['anexos'] as List<dynamic>)
              .map((e) => ArchiveModel.fromMap(e))
              .toList()
          : [],
      status: MateriaPrimaStatus.values[map['status']],
    );
  }

  factory MateriaPrimaModel.fromSupabaseMap(Map<String, dynamic> map) {
    final fabricanteSnapshot =
        FabricanteModel.fromMap(map['fabricante_model_raw']);
    final produtoSnapshot = BitolaModel.fromMap(map['bitola_raw']);
    // Dynamic linking: busca versão mais recente no cache reativo
    final fabricante = BackendClient.fabricantes.data.isNotEmpty
        ? BackendClient.fabricantes.getById(fabricanteSnapshot.id)
        : fabricanteSnapshot;
    final produto = BackendClient.bitolas.data.isNotEmpty
        ? BackendClient.bitolas.getById(produtoSnapshot.id)
        : produtoSnapshot;
    return MateriaPrimaModel(
      id: map['id'] as String,
      fabricanteModel: fabricante,
      produto: produto,
      corridaLote: map['corrida_lote'] as String,
      anexos: map['anexos'] != null
          ? (map['anexos'] as List<dynamic>)
              .map((e) => ArchiveModel.fromMap(e))
              .toList()
          : [],
      status: MateriaPrimaStatus.values[map['status']],
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'fabricante_model_raw': fabricanteModel.toMap(),
      'bitola_raw': produto.toMap(),
      'corrida_lote': corridaLote,
      'anexos': anexos.map((e) => e.toMap()).toList(),
      'status': status.index,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fabricanteModel': fabricanteModel.toMap(),
      'produto': produto.toMap(),
      'corridaLote': corridaLote,
      'anexos': anexos.map((e) => e.toMap()).toList(),
      'status': status.index,
    };
  }

  @override
  String toString() {
    return '${produto.labelMinified.replaceAll(' - ', ' ').replaceAll('Bitola ', '')} - ${fabricanteModel.nome} - $corridaLote';
  }
}
