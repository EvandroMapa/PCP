import 'dart:convert';
import 'dart:developer';
import 'package:aco_plus/app/app_repository.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/http/fcm/fcm_provider.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/push_notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/usuario/usuario_view_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final usuarioCtrl = UsuarioController();
UsuarioModel get usuario => usuarioCtrl.usuario!;

class UsuarioController {
  static final UsuarioController _instance = UsuarioController._();

  UsuarioController._();

  factory UsuarioController() => _instance;

  void setup() {
    BackendClient.usuarios.dataStream.listen.listen((list) {
      if (usuario != null) {
        final match = list.firstWhereOrNull((e) => e.id == usuario!.id);
        if (match != null && match != usuario) {
          usuarioStream.add(match);
        }
      }
    });
  }

  final AppStream<UsuarioModel?> usuarioStream = AppStream<UsuarioModel?>.seed(
    null,
  );
  UsuarioModel? get usuario => usuarioStream.value;

  final AppStream<UsuarioUtils> utilsStream = AppStream<UsuarioUtils>.seed(
    UsuarioUtils(),
  );
  UsuarioUtils get utils => utilsStream.value;

  final AppStream<UsuarioCreateModel> formStream =
      AppStream<UsuarioCreateModel>();
  UsuarioCreateModel get form => formStream.value;

  void init(UsuarioModel? usuario) {
    formStream.add(
      usuario != null ? UsuarioCreateModel.edit(usuario) : UsuarioCreateModel(),
    );
  }

  List<UsuarioModel> getUsuariosFiltered(
    String search,
    List<UsuarioModel> usuarios, {
    bool mostrarInativos = false,
  }) {
    List<UsuarioModel> filtered = [];
    if (search.length < 3) {
      filtered = List.from(usuarios);
    } else {
      for (final usuario in usuarios) {
        if (usuario.toString().toCompare.contains(search.toCompare)) {
          filtered.add(usuario);
        }
      }
    }
    
    // Filtrar inativos quando checkbox desmarcada
    if (!mostrarInativos) {
      filtered = filtered.where((u) => u.isAtivo).toList();
    }
    
    filtered.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return filtered;
  }

  Future<void> onConfirm(value, UsuarioModel? usuario) async {
    try {
      onValid();
      if (form.isEdit) {
        final edit = form.toUsuarioModel();
        await BackendClient.usuarios.update(edit);
      } else {
        await BackendClient.usuarios.add(form.toUsuarioModel());
      }
      pop(value);
      NotificationService.showPositive(
        'Usuário ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
      await BackendClient.usuarios.fetch();
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao realizar operação',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  /// Verifica se o usuário pode ser excluído (sem registros no audit_logs).
  Future<bool> verificarPodeExcluir(UsuarioModel usuario) async {
    try {
      final result = await SupabaseService.client
          .from('audit_logs')
          .select('id')
          .eq('usuario_id', usuario.id)
          .limit(1);
      return (result as List).isEmpty;
    } catch (e) {
      log('Erro ao verificar audit_logs: $e');
      return false; // Em caso de erro, bloqueia exclusão por segurança
    }
  }

  Future<void> onDelete(dynamic value, UsuarioModel usuario) async {
    // Verificar se o usuário tem histórico no audit_logs
    final podeExcluir = await verificarPodeExcluir(usuario);
    if (!podeExcluir) {
      // Não fecha o dialog anterior, mostra bloqueio informativo
      if (value is BuildContext) {
        pop(value); // Fecha dialog de confirmação
        showDialog(
          context: value,
          builder: (_) => AlertDialog(
            icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
            title: const Text('Exclusão Bloqueada'),
            content: const Text(
              'Este usuário possui registros no log de auditoria e não pode ser excluído.\n\n'
              'Para impedir o acesso, utilize a opção de inativar o usuário.',
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => pop(_),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
      }
      return;
    }

    await BackendClient.usuarios.delete(usuario);
    await BackendClient.usuarios.fetch();
    pop(value);
    NotificationService.showPositive(
      'Usuário Excluído',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );
  }

  /// Alterna o status ativo/inativo de um usuário.
  Future<void> toggleAtivo(UsuarioModel usuario) async {
    try {
      final novoStatus = !usuario.isAtivo;
      final atualizado = usuario.copyWith(isAtivo: novoStatus);
      await BackendClient.usuarios.update(atualizado);
      await BackendClient.usuarios.fetch();
      NotificationService.showPositive(
        novoStatus ? 'Usuário Ativado' : 'Usuário Inativado',
        '"${usuario.nome}" foi ${novoStatus ? 'ativado' : 'inativado'} com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao alterar status',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  void onValid() {
    String nomeForm = form.nome.text.trim();
    String emailForm = form.email.text.trim().toLowerCase();
    if (nomeForm.length < 2) {
      throw Exception('Nome deve conter no mínimo 3 caracteres');
    }
    if (emailForm.isEmpty) {
      throw Exception('Login inválido');
    }
    if (form.usuarioTipoId.isEmpty) {
      throw Exception('É obrigatório selecionar um Perfil de Acesso');
    }
    if (form.isEdit) {
      if (BackendClient.usuarios.data.any((e) =>
          e.email.toLowerCase().trim() == emailForm &&
          e.id.toString().trim() != form.id.toString().trim())) {
        throw Exception('Já existe um usuário com esse login');
      }
    } else {
      if (BackendClient.usuarios.data
          .any((e) => e.email.toLowerCase().trim() == emailForm)) {
        throw Exception('Já existe um usuário com esse login');
      }
    }
  }

  Future<void> getCurrentUser() async {
    try {
      UsuarioModel? user = await AppRepository.get();
      if (user != null) {
        final usuariosData = BackendClient.usuarios.data;
        if (usuariosData.isNotEmpty) {
          // Dados carregados — valida se o usuário ainda existe
          if (usuariosData.any((e) => e.id == user!.id)) {
            user = BackendClient.usuarios.getById(user.id);
            // Verificar se o usuário está ativo
            if (!user.isAtivo) {
              log('UsuarioController: Usuário inativo, limpando sessão');
              user = null;
              await AppRepository.clear();
            } else {
              AppRepository.add(user);
            }
          } else {
            // Usuário não existe mais no banco
            user = null;
            await AppRepository.clear();
          }
        }
        // Se data está vazio, mantém o user do SharedPreferences
        // (dados ainda não carregaram — não invalida a sessão)
      }
      usuarioStream.add(user);
    } catch (e) {
      log('UsuarioController: Erro no auto-login', error: e);
      usuarioStream.add(null);
    }
  }

  Future<void> setCurrentUser(UsuarioModel usuario, bool rememberMe) async {
    if (rememberMe) {
      await AppRepository.add(usuario);
    } else {
      await AppRepository.removeUser();
    }
    usuarioStream.add(usuario);
    FCMProvider.putToken();
  }

  Future<void> clearCurrentUser() async {
    // Registra logout ANTES de limpar o user
    await AuditService.registrar(
      acao: 'logout',
      modulo: 'sessao',
    );

    try {
      usuario?.deviceTokens.removeWhere((e) => e == deviceToken);
      // Update cirúrgico — só atualiza deviceTokens
      await SupabaseService.client
          .from('usuarios')
          .update({'deviceTokens': json.encode(usuario!.deviceTokens)})
          .eq('id', usuario!.id);
    } catch (e) {
      log('Erro ao limpar token do usuário: $e');
    }
    await AppRepository.removeUser();
    await AppRepository.clearCredentials();
    usuarioStream.add(null);
  }
}
