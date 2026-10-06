import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_form.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/usuario/usuario_tipo_controller.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

Future<void> showUsuarioTipoFormDialog(BuildContext context,
    {UsuarioTipoModel? tipo}) async {
  usuarioTipoCtrl.init(tipo);
  await showDialog(
    context: context,
    builder: (_) => const UsuarioTipoFormDialog(),
  );
}

class UsuarioTipoFormDialog extends StatefulWidget {
  const UsuarioTipoFormDialog({super.key});

  @override
  State<UsuarioTipoFormDialog> createState() => _UsuarioTipoFormDialogState();
}

class _UsuarioTipoFormDialogState extends State<UsuarioTipoFormDialog> {
  @override
  Widget build(BuildContext context) {
    return StreamOut<UsuarioTipoCreateModel>(
      stream: usuarioTipoCtrl.formStream.listen,
      builder: (_, form) => CadastroDialog(
        icon: Symbols.badge,
        titulo: form.isEdit ? 'Editar perfil de acesso' : 'Novo perfil de acesso',
        largura: 640,
        onSalvar: () async => usuarioTipoCtrl.onConfirm(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppField(
              label: 'Nome do perfil',
              hint: 'Ex.: Administrador, Operador, Vendedor',
              controllerObj: form.nome,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),

            // ── Tipo de acesso ──
            const CadastroSubtitulo('Tipo de acesso'),
            CadastroOpcao(
              titulo: 'Administrador',
              explicacao: 'Acesso completo, inclusive ao painel gerencial',
              valor: form.isAdministrador,
              onChanged: (v) => setState(() => form.isAdministrador = v),
            ),
            CadastroOpcao(
              titulo: 'Operador',
              explicacao: 'Usa a tela de ordens de produção (chão de fábrica)',
              valor: form.isOperador,
              onChanged: (v) => setState(() {
                form.isOperador = v;
                // Exclusivo: só pode ter um dos dois
                if (form.isExclusivo && form.isOperador) form.isArmador = false;
              }),
            ),
            CadastroOpcao(
              titulo: 'Armador',
              explicacao: 'Usa a tela de armação',
              valor: form.isArmador,
              onChanged: (v) => setState(() {
                form.isArmador = v;
                if (form.isExclusivo && form.isArmador) form.isOperador = false;
              }),
            ),
            if (form.isOperador || form.isArmador)
              CadastroOpcao(
                titulo: 'Acesso exclusivo',
                explicacao: 'Bloqueia a tela principal e permite só a tela dedicada'
                    '${form.isOperador ? ' (/operador)' : ''}'
                    '${form.isArmador ? ' (/armador)' : ''}',
                valor: form.isExclusivo,
                onChanged: (v) => setState(() {
                  form.isExclusivo = v;
                  // Ao marcar exclusivo com ambos, mantém só operador
                  if (form.isExclusivo && form.isOperador && form.isArmador) {
                    form.isArmador = false;
                  }
                }),
              ),
            const SizedBox(height: 14),

            // ── Permissões ──
            const CadastroSubtitulo('Permissões'),
            CadastroOpcao(
              titulo: 'Ver a aba Elementos',
              valor: form.isPermitirElementos,
              onChanged: (v) => setState(() => form.isPermitirElementos = v),
            ),
            CadastroOpcao(
              titulo: 'Editar elementos',
              valor: form.isPermitirEditarElementos,
              onChanged: (v) =>
                  setState(() => form.isPermitirEditarElementos = v),
            ),
            CadastroOpcao(
              titulo: 'Excluir pedidos',
              valor: form.isPermitirExcluirPedido,
              onChanged: (v) =>
                  setState(() => form.isPermitirExcluirPedido = v),
            ),
            CadastroOpcao(
              titulo: 'Ajustar estoque',
              valor: form.isPermitirAjusteEstoque,
              onChanged: (v) =>
                  setState(() => form.isPermitirAjusteEstoque = v),
            ),

            // ── O que pode fazer em clientes, pedidos e ordens ──
            if (!form.isExclusivo) ...[
              const SizedBox(height: 14),
              const CadastroSubtitulo('Clientes, pedidos e ordens'),
              LayoutBuilder(builder: (context, constraints) {
                final grupos = [
                  _grupoPermissoes(
                      'Clientes', Symbols.groups, form.permissaoCliente),
                  _grupoPermissoes(
                      'Pedidos', Symbols.list_alt, form.permissaoPedido),
                  _grupoPermissoes(
                      'Ordens', Symbols.assignment, form.permissaoOrdem),
                ];
                if (constraints.maxWidth < 520) {
                  return Column(
                    children: [
                      for (final g in grupos) ...[
                        g,
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < grupos.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: grupos[i]),
                    ],
                  ],
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _grupoPermissoes(
    String titulo,
    IconData icon,
    List<UserPermissionType> selecionadas,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.neutralLightest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.neutralDark),
              const SizedBox(width: 6),
              Text(titulo, style: AppCss.minimumBold.setSize(12.5)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: UserPermissionType.values.map((perm) {
              final ativo = selecionadas.contains(perm);
              return InkWell(
                onTap: () => setState(() {
                  if (ativo) {
                    selecionadas.remove(perm);
                  } else {
                    selecionadas.add(perm);
                  }
                }),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: ativo ? AppColors.primaryMain : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: ativo
                            ? AppColors.primaryMain
                            : AppColors.neutralLight),
                  ),
                  child: Text(
                    perm.label,
                    style: AppCss.minimumBold.setSize(11).setColor(
                        ativo ? Colors.white : AppColors.neutralDark),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
