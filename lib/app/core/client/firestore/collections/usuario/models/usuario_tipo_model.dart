class UsuarioTipoModel {
  final String id;
  final String nome;
  final bool isPermitirElementos;
  final bool isPermitirEditarElementos;
  final bool isPermitirExcluirPedido;
  final bool isPermitirAjusteEstoque;
  final bool isOperador;
  final bool isArmador;
  final bool isAdministrador;
  final bool isExclusivo;
  final DateTime createdAt;

  UsuarioTipoModel({
    required this.id,
    required this.nome,
    required this.isPermitirElementos,
    required this.isPermitirEditarElementos,
    required this.isPermitirExcluirPedido,
    required this.isPermitirAjusteEstoque,
    required this.isOperador,
    required this.isArmador,
    required this.isAdministrador,
    required this.isExclusivo,
    required this.createdAt,
  });

  factory UsuarioTipoModel.empty() => UsuarioTipoModel(
        id: '',
        nome: '',
        isPermitirElementos: false,
        isPermitirEditarElementos: false,
        isPermitirExcluirPedido: false,
        isPermitirAjusteEstoque: false,
        isOperador: false,
        isArmador: false,
        isAdministrador: false,
        isExclusivo: false,
        createdAt: DateTime.now(),
      );

  factory UsuarioTipoModel.fromSupabaseMap(Map<String, dynamic> map) {
    return UsuarioTipoModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      isPermitirElementos: map['permitir_elementos'] ?? false,
      isPermitirEditarElementos: map['permitir_editar_elementos'] ?? false,
      isPermitirExcluirPedido: map['permitir_excluir_pedido'] ?? false,
      isPermitirAjusteEstoque: map['permitir_ajuste_estoque'] ?? false,
      isOperador: map['is_operador'] ?? false,
      isArmador: map['is_armador'] ?? false,
      isAdministrador: map['is_administrador'] ?? false,
      isExclusivo: map['is_exclusivo'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    final map = {
      'nome': nome,
      'permitir_elementos': isPermitirElementos,
      'permitir_editar_elementos': isPermitirEditarElementos,
      'permitir_excluir_pedido': isPermitirExcluirPedido,
      'permitir_ajuste_estoque': isPermitirAjusteEstoque,
      'is_operador': isOperador,
      'is_armador': isArmador,
      'is_administrador': isAdministrador,
      'is_exclusivo': isExclusivo,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  @override
  String toString() {
    return 'UsuarioTipoModel(id: $id, nome: $nome, isPermitirElementos: $isPermitirElementos, isPermitirEditarElementos: $isPermitirEditarElementos, isPermitirExcluirPedido: $isPermitirExcluirPedido, isPermitirAjusteEstoque: $isPermitirAjusteEstoque, isOperador: $isOperador, isArmador: $isArmador, isAdministrador: $isAdministrador)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsuarioTipoModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
