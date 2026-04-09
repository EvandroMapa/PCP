import 'dart:convert';

class UsuarioTipoModel {
  final String id;
  final String nome;
  final bool isPermitirElementos;
  final bool isOperador;
  final DateTime createdAt;

  UsuarioTipoModel({
    required this.id,
    required this.nome,
    required this.isPermitirElementos,
    required this.isOperador,
    required this.createdAt,
  });

  factory UsuarioTipoModel.empty() => UsuarioTipoModel(
        id: '',
        nome: '',
        isPermitirElementos: false,
        isOperador: false,
        createdAt: DateTime.now(),
      );

  factory UsuarioTipoModel.fromSupabaseMap(Map<String, dynamic> map) {
    return UsuarioTipoModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      isPermitirElementos: map['permitir_elementos'] ?? false,
      isOperador: map['is_operador'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'nome': nome,
        'permitir_elementos': isPermitirElementos,
        'is_operador': isOperador,
      };

  @override
  String toString() {
    return 'UsuarioTipoModel(id: $id, nome: $nome, isPermitirElementos: $isPermitirElementos, isOperador: $isOperador)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsuarioTipoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
