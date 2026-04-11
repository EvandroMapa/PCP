
class UsuarioTipoModel {
  final String id;
  final String nome;
  final bool isPermitirElementos;
  final bool isOperador;
  final bool isArmador;
  final DateTime createdAt;

  UsuarioTipoModel({
    required this.id,
    required this.nome,
    required this.isPermitirElementos,
    required this.isOperador,
    required this.isArmador,
    required this.createdAt,
  });

  factory UsuarioTipoModel.empty() => UsuarioTipoModel(
        id: '',
        nome: '',
        isPermitirElementos: false,
        isOperador: false,
        isArmador: false,
        createdAt: DateTime.now(),
      );

  factory UsuarioTipoModel.fromSupabaseMap(Map<String, dynamic> map) {
    return UsuarioTipoModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      isPermitirElementos: map['permitir_elementos'] ?? false,
      isOperador: map['is_operador'] ?? false,
      isArmador: map['is_armador'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = {
      'nome': nome,
      'permitir_elementos': isPermitirElementos,
      'is_operador': isOperador,
      'is_armador': isArmador,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  @override
  String toString() {
    return 'UsuarioTipoModel(id: $id, nome: $nome, isPermitirElementos: $isPermitirElementos, isOperador: $isOperador, isArmador: $isArmador)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsuarioTipoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
