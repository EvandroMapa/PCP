import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/app_env.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';

import 'package:aco_plus/app/modules/audit/ui/audit_log_page.dart';
import 'package:aco_plus/app/modules/backup/ui/backups_page.dart';
import 'package:aco_plus/app/modules/modulo_importacao/ui/modulos_importacao_page.dart';
import 'package:aco_plus/app/modules/checklist/ui/checklists_page.dart';
import 'package:aco_plus/app/modules/step/ui/steps_page.dart';
import 'package:aco_plus/app/modules/tag/ui/tags_page.dart';
import 'package:aco_plus/app/modules/patio/ui/patio_tabs_page.dart';
import 'package:aco_plus/app/modules/usuario/ui/usuarios_page.dart';
import 'package:aco_plus/app/modules/usuario/ui/usuario_tipo_page.dart';
import 'package:aco_plus/app/modules/config/ui/general_settings_page.dart';
import 'package:aco_plus/app/modules/automatizacao/ui/automatizacao_page.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  @override
  void initState() {
    setWebTitle('Configurações');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        title: const Text(
          'Configurações',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _grupo('Pessoas e acesso', [
                    _item(Symbols.group, 'Usuários',
                        'Quem entra no sistema, login e perfil de cada um',
                        const UsuariosPage()),
                    _item(Symbols.badge, 'Perfis de acesso',
                        'O que cada tipo de usuário pode ver e fazer',
                        const UsuarioTipoPage()),
                  ]),
                  _grupo('Fluxo dos pedidos', [
                    _item(Symbols.view_kanban, 'Etapas',
                        'Colunas do Kanban: ordem, cor e regras de cada etapa',
                        const StepsPage()),
                    _item(Symbols.automation, 'Automações de etapas',
                        'Para onde o pedido vai sozinho conforme a produção avança',
                        const AutomatizacaoPage()),
                    _item(Symbols.sell, 'Etiquetas',
                        'Marcadores coloridos dos cartões',
                        const TagsPage()),
                    _item(Symbols.checklist, 'Modelos de checklist',
                        'Listas de conferência usadas nos pedidos',
                        const ChecklistsPage()),
                  ]),
                  _grupo('Pátio', [
                    _item(Symbols.grid_view, 'Cadastro de pátio',
                        'Pátios e boxes onde o material fica guardado',
                        const PatioTabsPage()),
                  ]),
                  _grupo('Sistema', [
                    _item(Symbols.tune, 'Configurações gerais',
                        'Empresa e logo, apontamento da produção, Kanban, PDF e manutenção',
                        const GeneralSettingsPage()),
                    _item(Symbols.upload_file, 'Módulos de importação',
                        'Integrações com sistemas externos',
                        const ModulosImportacaoPage()),
                    _item(Symbols.backup, 'Backup',
                        'Cópias de segurança dos dados',
                        const BackupsPage()),
                    _item(Symbols.history, 'Logs de auditoria',
                        'Quem fez o quê e quando',
                        const AuditLogPage()),
                  ]),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      kVersaoLabel,
                      textAlign: TextAlign.center,
                      style: AppCss.minimumRegular
                          .setSize(11.5)
                          .setColor(AppColors.neutralMedium),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grupo(String titulo, List<Widget> itens) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              titulo.toUpperCase(),
              style: AppCss.minimumBold
                  .setSize(11.5)
                  .setColor(AppColors.neutralMedium)
                  .copyWith(letterSpacing: 0.8),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.neutralLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < itens.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: AppColors.neutralLightest),
                  itens[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String titulo, String descricao, Widget page) {
    return InkWell(
      onTap: () => push(context, page),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.neutralLightest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: AppColors.neutralDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: AppCss.minimumBold.setSize(14.5)),
                  const SizedBox(height: 2),
                  Text(
                    descricao,
                    style: AppCss.minimumRegular
                        .setSize(12.5)
                        .setColor(AppColors.neutralMedium),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.neutralMedium),
          ],
        ),
      ),
    );
  }
}
