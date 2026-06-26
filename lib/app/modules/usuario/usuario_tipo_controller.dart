import 'dart:developer';

import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final usuarioTipoCtrl = UsuarioTipoController();

class UsuarioTipoController {
  static final UsuarioTipoController _instance = UsuarioTipoController._();
  UsuarioTipoController._();
  factory UsuarioTipoController() => _instance;

  final AppStream<List<UsuarioTipoModel>> tiposStream =
      BackendClient.usuarioTipos.dataStream;
  List<UsuarioTipoModel> get tipos => tiposStream.value;

  final AppStream<UsuarioTipoCreateModel> formStream =
      AppStream<UsuarioTipoCreateModel>();
  UsuarioTipoCreateModel get form => formStream.value;

  void init(UsuarioTipoModel? tipo) {
    formStream.add(
      tipo != null
          ? UsuarioTipoCreateModel.edit(tipo)
          : UsuarioTipoCreateModel(),
    );
  }

  Future<void> onConfirm(BuildContext context) async {
    try {
      if (form.nome.text.trim().isEmpty) {
        throw Exception('O nome do tipo é obrigatório');
      }

      final modelo = form.toModel();

      if (form.isEdit) {
        await BackendClient.usuarioTipos.update(modelo);
      } else {
        final resultado = await BackendClient.usuarioTipos.add(modelo);
        // Habilitar o novo perfil em todas as etapas do kanban
        if (resultado != null) {
          await _habilitarPerfilEmTodasEtapas(resultado.id);
        }
      }

      if (context.mounted) pop(context);
      NotificationService.showPositive(
        'Perfil de Usuário ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao salvar',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  /// Insere o perfil na tabela `step_roles` para todas as etapas existentes,
  /// garantindo que o perfil recém-criado já tenha acesso a todo o kanban.
  Future<void> _habilitarPerfilEmTodasEtapas(String perfilId) async {
    try {
      final etapas = FirestoreClient.steps.data;
      if (etapas.isEmpty) return;

      final registros = etapas
          .map((etapa) => {
                'step_id': etapa.id,
                'perfil_id': perfilId,
              })
          .toList();

      await SupabaseService.client.from('step_roles').insert(registros);
      // Recarregar etapas para refletir o novo perfil
      await FirestoreClient.steps.fetch();
    } catch (e) {
      log('Erro ao habilitar perfil nas etapas: $e');
    }
  }

  Future<void> onDelete(BuildContext context, UsuarioTipoModel tipo) async {
    try {
      // Verificar se há usuários vinculados
      final usuariosComEsteTipo =
          BackendClient.usuarios.data.where((u) => u.usuarioTipoId == tipo.id);
      if (usuariosComEsteTipo.isNotEmpty) {
        throw Exception(
            'Não é possível excluir um perfil que possui usuários vinculados.');
      }

      await BackendClient.usuarioTipos.delete(tipo);

      NotificationService.showPositive(
        'Perfil Excluído',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );

      // Audit
      AuditService.registrar(
        acao: 'excluir_perfil',
        modulo: 'usuario',
        entidadeId: tipo.id,
        entidadeLabel: tipo.nome,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao excluir',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }
}

class UsuarioTipoCreateModel {
  final String id;
  final TextEditingController nome = TextEditingController();
  bool isPermitirElementos = false;
  bool isPermitirEditarElementos = false;
  bool isPermitirExcluirPedido = false;
  bool isPermitirAjusteEstoque = false;
  bool isOperador = false;
  bool isArmador = false;
  bool isAdministrador = false;
  bool isExclusivo = false;
  bool isEdit = false;
  List<UserPermissionType> permissaoCliente = UserPermissionType.values.toList();
  List<UserPermissionType> permissaoPedido = UserPermissionType.values.toList();
  List<UserPermissionType> permissaoOrdem = UserPermissionType.values.toList();

  UsuarioTipoCreateModel()
      : id = '',
        isEdit = false;

  UsuarioTipoCreateModel.edit(UsuarioTipoModel m)
      : id = m.id,
        isEdit = true {
    nome.text = m.nome;
    isPermitirElementos = m.isPermitirElementos;
    isPermitirEditarElementos = m.isPermitirEditarElementos;
    isPermitirExcluirPedido = m.isPermitirExcluirPedido;
    isPermitirAjusteEstoque = m.isPermitirAjusteEstoque;
    isOperador = m.isOperador;
    isArmador = m.isArmador;
    isAdministrador = m.isAdministrador;
    isExclusivo = m.isExclusivo;
    permissaoCliente = List<UserPermissionType>.from(m.permissaoCliente);
    permissaoPedido = List<UserPermissionType>.from(m.permissaoPedido);
    permissaoOrdem = List<UserPermissionType>.from(m.permissaoOrdem);
  }

  UsuarioTipoModel toModel() => UsuarioTipoModel(
        id: isEdit ? id : '',
        nome: nome.text.trim(),
        isPermitirElementos: isPermitirElementos,
        isPermitirEditarElementos: isPermitirEditarElementos,
        isPermitirExcluirPedido: isPermitirExcluirPedido,
        isPermitirAjusteEstoque: isPermitirAjusteEstoque,
        isOperador: isOperador,
        isArmador: isArmador,
        isAdministrador: isAdministrador,
        isExclusivo: isExclusivo,
        createdAt: DateTime.now(),
        permissaoCliente: permissaoCliente,
        permissaoPedido: permissaoPedido,
        permissaoOrdem: permissaoOrdem,
      );
}
