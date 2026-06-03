import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/ordem_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_materia_prima_bitolas.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';

class OrdemHistoryTypeEditadaModel extends OrdemHistoryDataModel {
  final UsuarioModel user;
  final DateTime createdAt;
  final OrdemMateriaPrimaProdutos? materiaPrimaProdutos;
  final List<PedidoBitolaModel> adicionados;
  final List<PedidoBitolaModel> removidos;

  OrdemHistoryTypeEditadaModel({
    required this.user,
    required this.createdAt,
    required this.materiaPrimaProdutos,
    required this.adicionados,
    required this.removidos,
  });

  factory OrdemHistoryTypeEditadaModel.fromJson(Map<String, dynamic> json) {
    return OrdemHistoryTypeEditadaModel(
      user: UsuarioModel.fromJson(json['user']),
      createdAt: DateTime.parse(json['createdAt']),
      materiaPrimaProdutos: OrdemMateriaPrimaProdutos.fromJson(
        json['materiaPrimaProdutos'],
      ),
      adicionados: List<PedidoBitolaModel>.from(
        (json['adicionados'] ?? [])
            .map((e) => PedidoBitolaModel.fromMap(e))
            .toList(),
      ),
      removidos: List<PedidoBitolaModel>.from(
        (json['removidos'] ?? [])
            .map((e) => PedidoBitolaModel.fromMap(e))
            .toList(),
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'materiaPrimaProdutos': materiaPrimaProdutos?.toJson(),
      'adicionados': adicionados.map((e) => e.toMap()).toList(),
      'removidos': removidos.map((e) => e.toMap()).toList(),
    };
  }
}
