import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:flutter/material.dart';

enum PedidoTipo { cd, cda, outros }

extension PedidoTipoExtension on PedidoTipo {
  String get label {
    switch (this) {
      case PedidoTipo.cd:
        return 'Corte e Dobra';
      case PedidoTipo.cda:
        return 'Corte, Dobra e Armação';
      case PedidoTipo.outros:
        return 'Outros';
    }
  }

  Color get foregroundColor {
    switch (this) {
      case PedidoTipo.cd:
        return Colors.red;
      case PedidoTipo.cda:
        return Colors.green;
      case PedidoTipo.outros:
        return Colors.blue[700]!;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case PedidoTipo.cd:
        return Colors.red[100]!;
      case PedidoTipo.cda:
        return Colors.green[100]!;
      case PedidoTipo.outros:
        return Colors.blue[50]!;
    }
  }

  /// Retorna null para 'outros' (não há tag padrão automática)
  TagModel? get tagOrNull {
    switch (this) {
      case PedidoTipo.cd:
        return FirestoreClient.tags.cd;
      case PedidoTipo.cda:
        return FirestoreClient.tags.cda;
      case PedidoTipo.outros:
        return null;
    }
  }
}
