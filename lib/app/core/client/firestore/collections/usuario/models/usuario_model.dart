import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/usuario_role.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_permission_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';

class UsuarioModel {
  final String id;
  final String nome;
  final String email;
  final String senha;
  final UsuarioRole role; // Temporário para retrocompatibilidade
  final String usuarioTipoId;
  final UsuarioTipoModel? tipo;
  final List<StepModel> steps;
  final List<String> deviceTokens;
  final bool isAtivo;

  /// Permissões CRUD agora derivam do perfil (tipo).
  /// Se não há perfil vinculado, libera tudo por segurança (fallback).
  UserPermissionModel get permission => tipo != null
      ? UserPermissionModel(
          cliente: tipo!.permissaoCliente,
          pedido: tipo!.permissaoPedido,
          ordem: tipo!.permissaoOrdem,
        )
      : UserPermissionModel.all();

  bool get isAdmin =>
      (tipo?.isAdministrador ?? false) ||
      (tipo?.nome.toLowerCase() == 'administrador') ||
      role == UsuarioRole.administrador;

  bool get isOperador =>
      !isAdmin && (tipo?.isOperador ?? role == UsuarioRole.operador);
  bool get isArmador => !isAdmin && (tipo?.isArmador ?? false);
  bool get isNotOperador => isAdmin || (!isOperador && !isArmador);

  /// Flags de acesso bruto (sem exclusividade com admin).
  /// Usados APENAS para validação de acesso às rotas standalone.
  bool get temAcessoOperador => tipo?.isOperador ?? false;
  bool get temAcessoArmador => tipo?.isArmador ?? false;
  bool get temAcessoGerencial => isAdmin;

  /// Se true, o usuário NÃO pode acessar a rota / (app principal).
  /// Deve usar apenas as rotas dedicadas (/operador, /armador).
  bool get isExclusivo => tipo?.isExclusivo ?? false;

  bool get temAcessoElementos =>
      tipo?.isPermitirElementos ?? false;
  bool get podeEditarElementos =>
      tipo?.isPermitirEditarElementos ?? false;
  bool get podeExcluirPedido =>
      tipo?.isPermitirExcluirPedido ?? false;

  bool get podeAjustarEstoque =>
      tipo?.isPermitirAjusteEstoque ?? false;

  static UsuarioModel get system => UsuarioModel(
        id: 'system',
        nome: 'Sistema',
        email: 'system@pcpm2.com',
        senha: 'system',
        role: UsuarioRole.administrador,
        usuarioTipoId: '',
        tipo: null,
        steps: FirestoreClient.steps.data.map((e) => e.copyWith()).toList(),
        deviceTokens: [],
        isAtivo: true,
      );

  UsuarioModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.senha,
    required this.role,
    required this.usuarioTipoId,
    this.tipo,
    required this.steps,
    required this.deviceTokens,
    this.isAtivo = true,
  });

  UsuarioModel copyWith({
    String? id,
    String? nome,
    String? email,
    String? senha,
    UsuarioRole? role,
    String? usuarioTipoId,
    UsuarioTipoModel? tipo,
    List<StepModel>? steps,
    List<String>? deviceTokens,
    bool? isAtivo,
  }) {
    return UsuarioModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      senha: senha ?? this.senha,
      role: role ?? this.role,
      usuarioTipoId: usuarioTipoId ?? this.usuarioTipoId,
      tipo: tipo ?? this.tipo,
      steps: steps ?? this.steps,
      deviceTokens: deviceTokens ?? this.deviceTokens,
      isAtivo: isAtivo ?? this.isAtivo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'senha': senha,
      'role': role.index,
      'perfil_id': usuarioTipoId,
      'steps': steps.map((x) => x.toMap()).toList(),
      'deviceTokens': deviceTokens,
      'is_ativo': isAtivo,
    };
  }

  Map<String, dynamic> toMention() => {
        "id": id,
        "display": nome,
        "photo":
            "https://images.pexels.com/photos/220453/pexels-photo-220453.jpeg",
      };

  factory UsuarioModel.empty() => UsuarioModel(
        id: '',
        nome: '',
        email: '',
        senha: '',
        role: UsuarioRole.operador,
        usuarioTipoId: '',
        tipo: null,
        steps: [],
        deviceTokens: [],
        isAtivo: true,
      );

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      role: UsuarioRole.values[map['role'] is int ? map['role'] : 0],
      usuarioTipoId: (map['perfil_id'] ?? map['usuario_tipo_id'] ?? '').toString(),
      steps: [],
      deviceTokens: map['deviceTokens'] != null
          ? List<String>.from(map['deviceTokens'])
          : [],
      isAtivo: map['is_ativo'] ?? true,
    );
  }

  factory UsuarioModel.fromSupabaseMap(Map<String, dynamic> map) {
    final tipo = map['perfis'] != null
        ? UsuarioTipoModel.fromSupabaseMap(map['perfis'])
        : null;

    return UsuarioModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      role: _parseRole(map['role']),
      usuarioTipoId: (map['perfil_id'] ?? '').toString(),
      tipo: tipo,
      steps: map['steps'] != null
          ? List<Map<String, dynamic>>.from(map['steps'] is String
                  ? json.decode(map['steps'])
                  : map['steps'])
              .map((e) => StepModel.fromMap(e))
              .toList()
          : [],
      deviceTokens: map['deviceTokens'] != null
          ? List<String>.from(map['deviceTokens'] is String
              ? json.decode(map['deviceTokens'])
              : map['deviceTokens'])
          : [],
      isAtivo: map['is_ativo'] ?? true,
    );
  }

  static UsuarioRole _parseRole(dynamic role) {
    if (role is int) return UsuarioRole.values[role];
    if (role is String) {
      final idx = int.tryParse(role);
      if (idx != null) return UsuarioRole.values[idx];
      return UsuarioRole.values.firstWhere(
        (e) => e.name == role,
        orElse: () => UsuarioRole.operador,
      );
    }
    return UsuarioRole.operador;
  }

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'nome': nome,
        'email': email,
        'senha': senha,
        'role': role.index,
        'perfil_id': usuarioTipoId.isEmpty ? null : usuarioTipoId,
        'steps': json.encode(steps.map((x) => x.toMap()).toList()),
        'deviceTokens': json.encode(deviceTokens),
        'is_ativo': isAtivo,
      };

  String toJson() => json.encode(toMap());

  factory UsuarioModel.fromJson(String source) =>
      UsuarioModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UsuarioModel(id: $id, nome: $nome, email: $email, senha: $senha, role: $role, isAtivo: $isAtivo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UsuarioModel &&
        other.id == id &&
        other.nome == nome &&
        other.email == email &&
        other.senha == senha &&
        other.role == role &&
        other.isAtivo == isAtivo;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        nome.hashCode ^
        email.hashCode ^
        senha.hashCode ^
        role.hashCode ^
        isAtivo.hashCode;
  }
}
