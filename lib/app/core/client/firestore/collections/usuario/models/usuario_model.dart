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
  final UserPermissionModel permission;
  final List<StepModel> steps;
  final List<String> deviceTokens;

  bool get isOperador => tipo?.isOperador ?? role == UsuarioRole.operador;
  bool get isNotOperador => !isOperador;

  bool get temAcessoElementos => tipo?.isPermitirElementos ?? role == UsuarioRole.administrador;

  static UsuarioModel get system => UsuarioModel(
    id: 'system',
    nome: 'Sistema',
    email: 'system@pcpm2.com',
    senha: 'system',
    role: UsuarioRole.administrador,
    usuarioTipoId: '',
    tipo: null,
    permission: UserPermissionModel.all(),
    steps: FirestoreClient.steps.data.map((e) => e.copyWith()).toList(),
    deviceTokens: [],
  );

  UsuarioModel({
    required this.id,
    required this.nome,
    required this.email,
    required this.senha,
    required this.role,
    required this.usuarioTipoId,
    this.tipo,
    required this.permission,
    required this.steps,
    required this.deviceTokens,
  });

  UsuarioModel copyWith({
    String? id,
    String? nome,
    String? email,
    String? senha,
    UsuarioRole? role,
    String? usuarioTipoId,
    UsuarioTipoModel? tipo,
    UserPermissionModel? permission,
    List<StepModel>? steps,
    List<String>? deviceTokens,
  }) {
    return UsuarioModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      senha: senha ?? this.senha,
      role: role ?? this.role,
      usuarioTipoId: usuarioTipoId ?? this.usuarioTipoId,
      tipo: tipo ?? this.tipo,
      permission: permission ?? this.permission,
      steps: steps ?? this.steps,
      deviceTokens: deviceTokens ?? this.deviceTokens,
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
      'permission': permission.toMap(),
      'steps': steps.map((x) => x.toMap()).toList(),
      'deviceTokens': deviceTokens,
    };
  }

  Map<String, dynamic> toMention() => {
    "id": id,
    "display": nome,
    "photo": "https://images.pexels.com/photos/220453/pexels-photo-220453.jpeg",
  };

  factory UsuarioModel.empty() => UsuarioModel(
    id: '',
    nome: '',
    email: '',
    senha: '',
    role: UsuarioRole.operador,
    usuarioTipoId: '',
    tipo: null,
    permission: UserPermissionModel.all(),
    steps: [],
    deviceTokens: [],
  );

  factory UsuarioModel.fromMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      role: UsuarioRole.values[map['role'] is int ? map['role'] : 0],
      usuarioTipoId: (map['usuario_tipo_id'] ?? '').toString(),
      permission: map['permission'] != null
          ? UserPermissionModel.fromMap(map['permission'])
          : UserPermissionModel.all(),
      steps: [],
      deviceTokens: map['deviceTokens'] != null
          ? List<String>.from(map['deviceTokens'])
          : [],
    );
  }

  factory UsuarioModel.fromSupabaseMap(Map<String, dynamic> map) {
    return UsuarioModel(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      senha: map['senha'] ?? '',
      role: _parseRole(map['role']),
      usuarioTipoId: (map['perfil_id'] ?? '').toString(),
      tipo: map['perfis'] != null
          ? UsuarioTipoModel.fromSupabaseMap(map['perfis'])
          : null,
      permission: map['permission'] != null
          ? UserPermissionModel.fromMap(map['permission'] is String
              ? json.decode(map['permission'])
              : map['permission'])
          : UserPermissionModel.all(),
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
        'permission': json.encode(permission.toMap()),
        'steps': json.encode(steps.map((x) => x.toMap()).toList()),
        'deviceTokens': json.encode(deviceTokens),
      };

  String toJson() => json.encode(toMap());

  factory UsuarioModel.fromJson(String source) =>
      UsuarioModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'UsuarioModel(id: $id, nome: $nome, email: $email, senha: $senha, role: $role, permission: $permission)';
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
        other.permission == permission;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        nome.hashCode ^
        email.hashCode ^
        senha.hashCode ^
        role.hashCode ^
        permission.hashCode;
  }
}
