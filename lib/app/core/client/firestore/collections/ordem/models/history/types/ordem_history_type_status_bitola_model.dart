import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/ordem_history_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_status_bitolas.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';

class OrdemHistoryTypeStatusBitolaModel extends OrdemHistoryDataModel {
  final UsuarioModel user;
  final DateTime createdAt;
  final OrdemStatusProdutos statusProdutos;

  OrdemHistoryTypeStatusBitolaModel({
    required this.user,
    required this.createdAt,
    required this.statusProdutos,
  });

  factory OrdemHistoryTypeStatusBitolaModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrdemHistoryTypeStatusBitolaModel(
      user: UsuarioModel.fromJson(json['user']),
      createdAt: DateTime.parse(json['createdAt']),
      statusProdutos: OrdemStatusProdutos.fromJson(
        json['statusProdutos'],
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'statusProdutos': statusProdutos.toJson(),
    };
  }
}
