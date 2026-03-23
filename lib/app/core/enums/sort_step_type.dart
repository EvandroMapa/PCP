enum SortStepType {
  createdAtDesc,
  createdAtAsc,
  localizador,
  deliveryAtDesc,
  deliveryAtAsc,
}

extension SortStepTypeExt on SortStepType {
  String get label {
    switch (this) {
      case SortStepType.createdAtDesc:
        return 'Data de criação (mais recente primeiro)';
      case SortStepType.createdAtAsc:
        return 'Data de criação (mais antigo primeiro)';
      case SortStepType.localizador:
        return 'Nome do cartão (em ordem alfabética)';
      case SortStepType.deliveryAtDesc:
        return 'Data de entrega (mais recente primeiro)';
      case SortStepType.deliveryAtAsc:
        return 'Data de entrega (mais antigo primeiro)';
    }
  }
}
