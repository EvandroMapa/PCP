class FabricanteModel {
  final String id;
  final String nome;
  final String? descricao; // Ramo / tipo de fornecedor
  final String? contato;  // Nome da pessoa de contato (A/C)
  final String? telefone; // WhatsApp (ex: 5511999999999)
  final String? email;

  FabricanteModel({
    required this.id,
    required this.nome,
    this.descricao,
    this.contato,
    this.telefone,
    this.email,
  });

  static FabricanteModel empty() =>
      FabricanteModel(id: 'register_unavailable', nome: 'Sem Registro');

  bool get temWhatsApp => telefone != null && telefone!.isNotEmpty;
  bool get temEmail => email != null && email!.isNotEmpty;
  bool get temContato => contato != null && contato!.isNotEmpty;
  bool get temDescricao => descricao != null && descricao!.isNotEmpty;

  factory FabricanteModel.fromMap(Map<String, dynamic> map) {
    return FabricanteModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
      descricao: map['descricao'] as String?,
      contato: map['contato'] as String?,
      telefone: map['telefone'] as String?,
      email: map['email'] as String?,
    );
  }

  factory FabricanteModel.fromSupabaseMap(Map<String, dynamic> map) {
    return FabricanteModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
      descricao: map['descricao'] as String?,
      contato: map['contato'] as String?,
      telefone: map['telefone'] as String?,
      email: map['email'] as String?,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'contato': contato,
      'telefone': telefone,
      'email': email,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'descricao': descricao,
      'contato': contato,
      'telefone': telefone,
      'email': email,
    };
  }
}
