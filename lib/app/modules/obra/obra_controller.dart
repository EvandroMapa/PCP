import 'dart:developer';

import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/cliente/cliente_supabase_collection.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/modules/obra/obra_view_model.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final obraCtrl = ObraController();

class ObraController {
  static final ObraController _instance = ObraController._();

  ObraController._();

  factory ObraController() => _instance;

  final AppStream<ObraCreateModel> formStream = AppStream<ObraCreateModel>();
  ObraCreateModel get form => formStream.value;

  /// clienteId corrente — definido antes de abrir ObraCreatePage
  String? _clienteId;

  bool get _devePersisteNoBanco => _clienteId != null;

  ClienteSupabaseCollection get _supabaseClientes =>
      FirestoreClient.clientes as ClienteSupabaseCollection;

  void init(ObraModel? obra, EnderecoModel? enderecoModel,
      {String? clienteId}) {
    _clienteId = clienteId;
    log('[ObraController] init — clienteId=$clienteId isEdit=${obra != null}');
    formStream.add(
      obra != null ? ObraCreateModel.edit(obra) : ObraCreateModel(),
    );
    if (!form.isEdit) {
      form.endereco = enderecoModel;
      formStream.update();
    }
  }

  Future<void> onConfirm(BuildContext context) async {
    log('[ObraController] onConfirm — clienteId=$_clienteId isEdit=${form.isEdit}');
    try {
      onValid();
      final obra = formStream.value.toObraModel();
      log('[ObraController] obra gerada: ${obra.descricao} id=${obra.id}');

      if (_devePersisteNoBanco) {
        log('[ObraController] persistindo no banco...');
        if (form.isEdit) {
          await _supabaseClientes.updateObra(obra, _clienteId!);
          log('[ObraController] updateObra OK');
        } else {
          await _supabaseClientes.addObra(obra, _clienteId!);
          log('[ObraController] addObra OK');
        }
      } else {
        log('[ObraController] AVISO: clienteId nulo — obra NÃO gravada no banco!');
      }

      if (context.mounted) {
        Navigator.pop(context, obra);
      }

      NotificationService.showPositive(
        'Obra ${form.isEdit ? 'Editada' : 'Adicionada'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e, st) {
      log('[ObraController] ERRO em onConfirm: $e\n$st');
      NotificationService.showNegative(
        'Erro ao salvar obra',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> onDelete(BuildContext context, ObraModel obra) async {
    log('[ObraController] onDelete — id=${obra.id} clienteId=$_clienteId');
    try {
      if (_devePersisteNoBanco) {
        await _supabaseClientes.deleteObra(obra.id);
        log('[ObraController] deleteObra OK');
      }
      if (context.mounted) {
        Navigator.pop(context, obraDeleteObj);
      }
      NotificationService.showPositive(
        'Obra Excluída',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e, st) {
      log('[ObraController] ERRO em onDelete: $e\n$st');
      NotificationService.showNegative(
        'Erro ao excluir obra',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> salvarEndereco(String obraId, EnderecoModel endereco) async {
    try {
      log('[ObraController] salvarEndereco — obraId=$obraId');
      await _supabaseClientes.updateObraEndereco(obraId, endereco);
      log('[ObraController] salvarEndereco OK');
    } catch (e, st) {
      log('[ObraController] ERRO em salvarEndereco: $e\n$st');
      NotificationService.showNegative(
        'Erro ao salvar endereço',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  void onValid() {
    if (form.descricao.text.length < 2) {
      throw Exception('Descrição deve conter no mínimo 3 caracteres');
    }
    if (form.status == null) {
      throw Exception('Selecione um status para a obra');
    }
  }
}
