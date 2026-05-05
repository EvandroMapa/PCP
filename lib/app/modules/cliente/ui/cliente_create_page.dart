import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';

import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_multiple_registers.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/done_button.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/enums/obra_status.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/cliente/cliente_controller.dart';
import 'package:aco_plus/app/modules/cliente/cliente_view_model.dart';
import 'package:aco_plus/app/modules/obra/ui/obra_create_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:cpf_cnpj_validator/cnpj_validator.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import 'package:flutter/material.dart';

enum _ClienteSection { dadosGerais, obras }

extension _ClienteSectionExt on _ClienteSection {
  String get label => switch (this) {
        _ClienteSection.dadosGerais => 'Dados Gerais',
        _ClienteSection.obras => 'Obras',
      };

  IconData get icon => switch (this) {
        _ClienteSection.dadosGerais => Icons.badge_outlined,
        _ClienteSection.obras => Icons.construction_outlined,
      };
}

class ClienteCreatePage extends StatefulWidget {
  final ClienteModel? cliente;
  final bool isFromOrder;
  const ClienteCreatePage({this.cliente, this.isFromOrder = false, super.key});

  @override
  State<ClienteCreatePage> createState() => _ClienteCreatePageState();
}

class _ClienteCreatePageState extends State<ClienteCreatePage> {
  _ClienteSection _selected = _ClienteSection.dadosGerais;
  String _initialSnapshot = '';
  bool _clienteSalvo = false;

  String _snapshot(ClienteCreateModel form) =>
      '${form.nome.text}|${form.telefone.text}|${form.cpf.text}';

  bool get _isDirty => _snapshot(clienteCtrl.form) != _initialSnapshot;

  bool get _obrasBlockedByDirty =>
      _isDirty || (!clienteCtrl.form.isEdit && !_clienteSalvo);

  @override
  void initState() {
    setWebTitle(widget.cliente != null ? 'Editar Cliente' : 'Novo Cliente');

    // Ao editar, busca a versão mais atualizada do cliente no dataStream
    // (widget.cliente pode ter sido capturado antes do fetch completar)
    final clienteAtualizado = widget.cliente != null
        ? FirestoreClient.clientes.getById(widget.cliente!.id)
        : null;

    clienteCtrl.init(
      clienteAtualizado?.id == widget.cliente?.id ? clienteAtualizado : widget.cliente,
    );
    _initialSnapshot = _snapshot(clienteCtrl.form);
    _clienteSalvo = widget.cliente != null;

    // Força recarregamento dos dados para garantir obras atualizadas
    if (widget.cliente != null) {
      FirestoreClient.clientes.fetch().then((_) {
        if (!mounted) return;
        final fresh = FirestoreClient.clientes.getById(widget.cliente!.id);
        if (fresh.id.isNotEmpty) {
          clienteCtrl.form.obras = List.from(fresh.obras);
          clienteCtrl.formStream.update();
        }
      });
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            if (_isDirty) {
              final confirm = await showConfirmDialog(
                'Deseja realmente sair?',
                widget.cliente != null
                    ? 'A edição que realizou será perdida.'
                    : 'Os dados do cliente serão perdidos.',
              );
              if (confirm && context.mounted) pop(context);
            } else {
              pop(context);
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          '${clienteCtrl.form.isEdit ? 'Editar' : 'Adicionar'} Cliente',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          if ((widget.cliente != null &&
                  usuario.permission.cliente
                      .contains(UserPermissionType.update)) ||
              (widget.cliente == null &&
                  usuario.permission.cliente
                      .contains(UserPermissionType.create)))
            IconLoadingButton(
              () async {
                await clienteCtrl.onConfirm(
                  context,
                  widget.cliente,
                  widget.isFromOrder,
                );
                if (mounted) {
                  setState(() {
                    _initialSnapshot = _snapshot(clienteCtrl.form);
                    _clienteSalvo = true;
                  });
                }
              },
            ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: clienteCtrl.formStream.listen,
        builder: (_, form) => Row(
          children: [
            _buildSidebar(form),
            Expanded(child: _buildContent(form)),
          ],
        ),
      ),
    );
  }

  // ── Sidebar ────────────────────────────────────────────────────────────────

  Widget _buildSidebar(ClienteCreateModel form) {
    return Container(
      width: 60,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          _buildSidebarPreview(form),
          const SizedBox(height: 8),
          ..._ClienteSection.values.map((s) => _buildMenuItem(s)),
          const Spacer(),
          if (form.isEdit &&
              usuario.permission.cliente.contains(UserPermissionType.delete))
            _buildSidebarDelete(form),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSidebarPreview(ClienteCreateModel form) {
    return Tooltip(
      message: form.nome.text.isEmpty ? 'Novo Cliente' : form.nome.text,
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primaryMain,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryMain.withValues(alpha: 0.5),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            form.nome.text.isEmpty ? '?' : form.nome.text[0].toUpperCase(),
            style: AppCss.mediumBold.setColor(AppColors.white).setSize(14),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(_ClienteSection section) {
    final isSelected = _selected == section;
    final isBlocked =
        section == _ClienteSection.obras && _obrasBlockedByDirty;
    final tooltipMsg = isBlocked
        ? (_isDirty
            ? 'Salve as alterações antes de acessar Obras'
            : 'Salve o cliente primeiro')
        : section.label;

    return Tooltip(
      message: tooltipMsg,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () {
          if (isBlocked) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                icon: Icon(Icons.info_outline,
                    size: 40, color: Colors.orange[700]),
                title: Text(
                    _isDirty ? 'Alterações não salvas' : 'Cliente não salvo'),
                content: Text(_isDirty
                    ? 'Salve as alterações do cliente antes de gerenciar obras.'
                    : 'Salve o cliente primeiro para gerenciar suas obras.'),
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMain),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Entendi'),
                  ),
                ],
              ),
            );
            return;
          }
          setState(() => _selected = section);
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryMain.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: AppColors.primaryMain.withValues(alpha: 0.20))
                : null,
          ),
          child: Icon(
            section.icon,
            size: 18,
            color: isBlocked
                ? Colors.grey[300]
                : isSelected
                    ? AppColors.primaryMain
                    : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarDelete(ClienteCreateModel form) {
    return Tooltip(
      message: 'Excluir ${form.nome.text}',
      preferBelow: false,
      child: InkWell(
        onTap: () => clienteCtrl.onDelete(context, widget.cliente!),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
        ),
      ),
    );
  }

  // ── Conteúdo principal ─────────────────────────────────────────────────────

  Widget _buildContent(ClienteCreateModel form) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(_selected),
        child: _buildSectionContent(form),
      ),
    );
  }

  Widget _buildSectionContent(ClienteCreateModel form) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Icon(_selected.icon, color: AppColors.primaryMain, size: 20),
            const SizedBox(width: 12),
            Text(_selected.label.toUpperCase(),
                style: AppCss.mediumBold.setSize(16).setLetterSpacing(1)),
          ],
        ),
        const SizedBox(height: 24),
        switch (_selected) {
          _ClienteSection.dadosGerais => _buildDadosGerais(form),
          _ClienteSection.obras => _buildObras(form),
        },
      ],
    );
  }

  // ── Dados gerais ───────────────────────────────────────────────────────────

  Widget _buildDadosGerais(ClienteCreateModel form) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (form.isEdit) ...[
            AppField(
              label: 'Código',
              controllerObj:
                  TextEditingController(text: form.codigo.toString()),
              isDisable: true,
            ),
            const SizedBox(height: 16),
          ],
          AppField(
            label: 'Nome',
            controller: form.nome,
            onChanged: (_) => clienteCtrl.formStream.update(),
          ),
          const SizedBox(height: 16),
          AppField(
            label: 'Telefone',
            hint: '(00) 00000-000',
            controller: form.telefone,
            onChanged: (_) => clienteCtrl.formStream.update(),
          ),
          const SizedBox(height: 16),
          AppField(
            label: 'CPF/CNPJ',
            required: false,
            controller: form.cpf,
            onChanged: (value) {
              if (value.length == 11 && CPFValidator.isValid(form.cpf.text)) {
                form.cpf.updateMask('000.000.000-00');
              } else if (value.length == 14 &&
                  CNPJValidator.isValid(form.cpf.text)) {
                form.cpf.updateMask('00.000.000/0000-00');
              } else {
                form.cpf.updateMask('00000000000000000');
              }
              clienteCtrl.formStream.update();
            },
          ),
        ],
      ),
    );
  }

  // ── Obras ──────────────────────────────────────────────────────────────────

  Widget _buildObras(ClienteCreateModel form) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AppMultipleRegisters<ObraModel>(
        icon: Icons.business_outlined,
        title: 'Gerenciar Obras',
        // clienteId é passado para que ObraController persista direto no banco
        createPage: ObraCreatePage(
          endereco: form.endereco,
          clienteId: form.id,
        ),
        onEdit: (obraForm) async {
          // O ObraController já persiste a edição/exclusão via clienteId.
          // Aqui apenas sincronizamos a lista local para refletir na UI.
          final obra = await push(
            context,
            ObraCreatePage(obra: obraForm, clienteId: form.id),
          ) as ObraModel?;

          if (obra == null) return;

          final idx =
              form.obras.map((e) => e.id).toList().indexOf(obraForm.id);
          if (idx < 0) return;

          if (obra.id != 'delete') {
            form.obras[idx] = obra;
          } else {
            form.obras.removeAt(idx);
          }
          clienteCtrl.formStream.update();
        },
        onAdd: (novaObra) async {
          // A obra já foi persistida pelo ObraController.
          // Apenas refletimos na lista local.
          form.obras.add(novaObra);
          clienteCtrl.formStream.update();
        },
        itens: form.obras,
        titleBuilder: (e) => Row(
          children: [
            Expanded(
              child: Text(
                e.descricao,
                style: AppCss.minimumBold.setSize(14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: e.status.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: e.status.color.withValues(alpha: 0.2)),
              ),
              child: Text(
                e.status.label.toUpperCase(),
                style:
                    AppCss.minimumBold.setSize(10).setColor(e.status.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
