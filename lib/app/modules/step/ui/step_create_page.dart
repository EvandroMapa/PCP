import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_color_picker.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/done_button.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/step/step_controller.dart';
import 'package:aco_plus/app/modules/step/step_shipping_view_model.dart';
import 'package:aco_plus/app/modules/step/step_view_model.dart';
import 'package:flutter/material.dart';

// Definição das seções do menu
enum _StepSection {
  identidade,
  fluxo,
  permissoes,
  acompanhamento,
  configuracoes,
}

extension _StepSectionExt on _StepSection {
  String get label => switch (this) {
        _StepSection.identidade => 'Identidade',
        _StepSection.fluxo => 'Fluxo',
        _StepSection.permissoes => 'Permissões',
        _StepSection.acompanhamento => 'Acompanhamento',
        _StepSection.configuracoes => 'Configurações',
      };

  IconData get icon => switch (this) {
        _StepSection.identidade => Icons.label_outline,
        _StepSection.fluxo => Icons.account_tree_outlined,
        _StepSection.permissoes => Icons.lock_outline,
        _StepSection.acompanhamento => Icons.local_shipping_outlined,
        _StepSection.configuracoes => Icons.tune_outlined,
      };
}

class StepCreatePage extends StatefulWidget {
  final StepModel? step;
  const StepCreatePage({this.step, super.key});

  @override
  State<StepCreatePage> createState() => _StepCreatePageState();
}

class _StepCreatePageState extends State<StepCreatePage> {
  _StepSection _selected = _StepSection.identidade;
  String _initialSnapshot = '';

  String _snapshot(StepCreateModel form) =>
      '${form.name.text}|${form.color.toARGB32()}'
      '|${form.fromSteps.map((e) => e.id).join(',')}'
      '|${form.moveRoles.join(',')}'
      '|${form.isShipping}|${form.shipping?.description.text ?? ""}'
      '|${form.isArchivedAvailable}|${form.isPermiteProducao}'
      '|${form.considerarConsumoRelatorioPedidos}'
      '|${form.isExibirArmacao}|${form.isExibirGraficoCDA}'
      '|${form.isAcceptWithoutElements}|${form.isAcceptSemEndereco}|${form.isConsiderarTotalProducao}'
      '|${form.isMarcarEntregue}|${form.isAcceptSemDataEntrega}|${form.isAcceptSemPedidoFinanceiro}';

  @override
  void initState() {
    setWebTitle('Nova Etapa');
    stepCtrl.init(widget.step);
    // Captura o estado inicial após o frame para comparar ao sair
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialSnapshot = _snapshot(stepCtrl.form);
    });
    super.initState();
  }

  Future<bool> _onWillPop() async {
    final isDirty = _snapshot(stepCtrl.form) != _initialSnapshot;
    if (!isDirty) return true;

    return await showConfirmDialog(
      'Deseja realmente sair?',
      widget.step != null
          ? 'A edição que realizou será perdida'
          : 'Os dados da Etapa serão perdidos.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: stepCtrl.formStream.listen,
      builder: (_, form) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (await _onWillPop()) {
            if (context.mounted) pop(context);
          }
        },
        child: AppScaffold(
          resizeAvoid: true,
          appBar: AppBar(
            leading: IconButton(
              onPressed: () async {
                if (await _onWillPop()) {
                  if (context.mounted) pop(context);
                }
              },
              icon: Icon(Icons.arrow_back, color: AppColors.white),
            ),
            title: StreamOut(
              stream: stepCtrl.formStream.listen,
              builder: (_, form) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${form.isEdit ? 'Editar' : 'Nova'} Etapa',
                    style: AppCss.largeBold.setColor(AppColors.white),
                  ),
                  if (form.name.text.isNotEmpty)
                    Text(
                      form.name.text,
                      style: AppCss.minimumRegular
                          .setColor(AppColors.white.withValues(alpha: 0.7)),
                    ),
                ],
              ),
            ),
            actions: [
              IconLoadingButton(
                () async => await stepCtrl.onConfirm(context, widget.step),
              ),
            ],
            backgroundColor: AppColors.primaryMain,
            elevation: 0,
          ),
          body: StreamOut(
            stream: stepCtrl.formStream.listen,
            builder: (_, form) => _buildLayout(form),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(StepCreateModel form) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Sidebar ──────────────────────────────────────────
        _buildSidebar(form),

        // ── Conteúdo ─────────────────────────────────────────
        Expanded(
          child: Container(
            color: AppColors.neutralLightest,
            child: _buildContent(form),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // SIDEBAR
  // ─────────────────────────────────────────────────────────

  Widget _buildSidebar(StepCreateModel form) {
    return Container(
      width: 60,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Preview da cor da etapa
          _buildSidebarPreview(form),

          const SizedBox(height: 8),

          // Itens do menu
          ..._StepSection.values.map((section) => _buildMenuItem(section)),

          const Spacer(),

          // Botão excluir no fundo do sidebar
          if (form.isEdit)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Tooltip(
                message: 'Excluir Etapa',
                preferBelow: false,
                child: InkWell(
                  onTap: () => stepCtrl.onDelete(context, widget.step!),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.30)),
                    ),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSidebarPreview(StepCreateModel form) {
    return Tooltip(
      message: form.name.text.isEmpty ? 'Nova Etapa' : form.name.text,
      preferBelow: false,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: form.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: form.color.withValues(alpha: 0.5),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(_StepSection section) {
    final isSelected = _selected == section;
    return Tooltip(
      message: section.label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () => setState(() => _selected = section),
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
            color: isSelected ? AppColors.primaryMain : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // CONTEÚDO POR SEÇÃO
  // ─────────────────────────────────────────────────────────

  Widget _buildContent(StepCreateModel form) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(
        key: ValueKey(_selected),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionHeader(_selected.label, _selected.icon),
            const SizedBox(height: 20),
            ..._buildSectionContent(form),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSectionContent(StepCreateModel form) {
    return switch (_selected) {
      _StepSection.identidade => _sectionIdentidade(form),
      _StepSection.fluxo => _sectionFluxo(form),
      _StepSection.permissoes => _sectionPermissoes(form),
      _StepSection.acompanhamento => _sectionAcompanhamento(form),
      _StepSection.configuracoes => _sectionConfiguracoes(form),
    };
  }

  // ── Identidade ──────────────────────────────────────────
  List<Widget> _sectionIdentidade(StepCreateModel form) => [
        _card(children: [
          _fieldLabel('Nome da Etapa'),
          const SizedBox(height: 8),
          AppField(
            label: '',
            controller: form.name,
            hint: 'Ex: Corte, Dobra, Armação...',
            onChanged: (_) => stepCtrl.formStream.update(),
          ),
          const SizedBox(height: 20),
          _fieldLabel('Cor da Etapa'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppColorPicker(
                  label: '',
                  color: form.color,
                  onChanged: (e) {
                    form.color = e;
                    stepCtrl.formStream.update();
                  },
                ),
              ),
              const SizedBox(width: 20),
              // Preview da badge da etapa
              Column(
                children: [
                  Text('Preview',
                      style: AppCss.minimumRegular
                          .setColor(AppColors.neutralMedium)),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: form.color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: form.color.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      form.name.text.isEmpty ? 'Etapa' : form.name.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ]),
      ];

  // ── Fluxo ────────────────────────────────────────────────
  List<Widget> _sectionFluxo(StepCreateModel form) => [
        _card(children: [
          _fieldLabel('Recebe pedidos de'),
          const SizedBox(height: 4),
          Text(
            'Selecione as etapas que podem enviar pedidos para esta.',
            style: AppCss.minimumRegular.setColor(AppColors.neutralMedium),
          ),
          const SizedBox(height: 12),
          AppDropDownList<StepModel>(
            label: '',
            addeds: form.fromSteps,
            itens: FirestoreClient.steps.data
                .where((e) => e.id != form.id)
                .toList(),
            itemLabel: (e) => e.name,
            onChanged: () => stepCtrl.formStream.add(form),
          ),
        ]),
      ];

  // ── Permissões ───────────────────────────────────────────
  List<Widget> _sectionPermissoes(StepCreateModel form) => [
        _card(children: [
          _fieldLabel('Quem pode mover pedidos para esta etapa?'),
          const SizedBox(height: 4),
          Text(
            'Se nenhum perfil for selecionado, todos os usuários poderão movimentar.',
            style: AppCss.minimumRegular.setColor(AppColors.neutralMedium),
          ),
          const SizedBox(height: 12),
          AppDropDownList<UsuarioTipoModel>(
            label: '',
            addeds: form.addedTipos,
            itens: AppSupabaseClient.usuarioTipos.data,
            itemLabel: (e) => e.nome,
            onChanged: () {
              form.moveRoles = form.addedTipos.map((t) => t.id).toList();
              stepCtrl.formStream.update();
            },
          ),
        ]),
        if (form.addedTipos.isEmpty) ...[
          const SizedBox(height: 12),
          _infoBox(
            icon: Icons.info_outline,
            text:
                'Sem restrição — todos os usuários podem mover pedidos nesta etapa.',
          ),
        ],
      ];

  // ── Acompanhamento ───────────────────────────────────────
  List<Widget> _sectionAcompanhamento(StepCreateModel form) => [
        _card(children: [
          _switchOption(
            icon: Icons.local_shipping_outlined,
            label: 'Acompanhamento do Cliente',
            description: 'Ativa notificação de progresso visível ao cliente.',
            value: form.isShipping,
            onChanged: (_) {
              form.isShipping = !form.isShipping;
              form.shipping =
                  form.isShipping ? StepShippingCreateModel() : null;
              stepCtrl.formStream.update();
            },
          ),
          if (form.isShipping) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            _fieldLabel('Mensagem exibida ao cliente'),
            const SizedBox(height: 8),
            AppField(
              label: '',
              controller: form.shipping!.description,
              hint: 'Ex: Seu pedido está em fase de corte...',
              maxLines: 3,
              onChanged: (_) => stepCtrl.formStream.update(),
            ),
          ],
        ]),
      ];

  // ── Configurações ────────────────────────────────────────
  List<Widget> _sectionConfiguracoes(StepCreateModel form) => [
        _card(children: [
          _switchOption(
            icon: Icons.archive_outlined,
            label: 'Permite arquivamento',
            description: 'Pedidos nesta etapa podem ser arquivados.',
            value: form.isArchivedAvailable,
            onChanged: (_) {
              form.isArchivedAvailable = !form.isArchivedAvailable;
              stepCtrl.formStream.update();
            },
          ),
          const Divider(height: 28),
          _switchOption(
            icon: Icons.precision_manufacturing_outlined,
            label: 'Entrada em Produção',
            description: 'Permite registrar entrada de pedidos em produção.',
            value: form.isPermiteProducao,
            onChanged: (_) {
              form.isPermiteProducao = !form.isPermiteProducao;
              stepCtrl.formStream.update();
            },
          ),
          const Divider(height: 28),
          _switchOption(
            icon: Icons.bar_chart_outlined,
            label: 'Consumo no Relatório',
            description:
                'Considera esta etapa no relatório de consumo de pedidos.',
            value: form.considerarConsumoRelatorioPedidos,
            onChanged: (_) {
              form.considerarConsumoRelatorioPedidos =
                  !form.considerarConsumoRelatorioPedidos;
              stepCtrl.formStream.update();
            },
          ),
          const Divider(height: 28),
          _switchOption(
            icon: Icons.construction_outlined,
            label: 'Módulo de Armação',
            description: 'Exibe pedidos desta etapa no módulo de armação.',
            value: form.isExibirArmacao,
            onChanged: (_) {
              form.isExibirArmacao = !form.isExibirArmacao;
              stepCtrl.formStream.update();
            },
          ),
          const Divider(height: 28),
          _switchOption(
            icon: Icons.donut_large_outlined,
            label: 'Gráfico CDA no Kanban',
            description:
                'Mostra o gráfico CDA nos cartões do Kanban desta etapa.',
            value: form.isExibirGraficoCDA,
            onChanged: (_) {
              form.isExibirGraficoCDA = !form.isExibirGraficoCDA;
              stepCtrl.formStream.update();
            },
          ),
          const Divider(height: 28),
          _switchOption(
            icon: Icons.playlist_add_check_outlined,
            label: 'Aceitar pedidos sem elementos cadastrados',
            description:
                'Pedidos CD e CDA sem elementos só podem ENTRAR nesta etapa se esta opção estiver ativa.',
            value: form.isAcceptWithoutElements,
            onChanged: (_) {
              form.isAcceptWithoutElements = !form.isAcceptWithoutElements;
              stepCtrl.formStream.update();
            },
          ),
          const Divider(height: 28),
          _switchOption(
            icon: Icons.location_off_outlined,
            label: 'Aceitar pedidos sem endereço na obra',
            description:
                'Pedidos cuja obra não tenha endereço ou coordenadas cadastrados só podem ENTRAR nesta etapa se esta opção estiver ativa.',
            value: form.isAcceptSemEndereco,
            onChanged: (_) {
              form.isAcceptSemEndereco = !form.isAcceptSemEndereco;
              stepCtrl.formStream.update();
            },
          ),
          const Divider(height: 28),
          _switchOption(
            icon: Icons.functions_outlined,
            label: 'Considerar no Total em Produção',
            description: 'Soma pedidos desta etapa no KPI "Total em Produção" (Gestão à Vista).',
            value: form.isConsiderarTotalProducao,
            onChanged: (_) {
              form.isConsiderarTotalProducao = !form.isConsiderarTotalProducao;
              stepCtrl.formStream.update();
            },
          ),
          const Divider(height: 28),
          _switchOption(
            icon: Icons.check_circle_outline,
            label: 'Marcar pedidos como Entregues',
            description:
                'Pedidos que entrarem nesta etapa serão automaticamente marcados como entregues. Ao sair desta etapa, o status de entregue é removido.',
            value: form.isMarcarEntregue,
            onChanged: (_) {
              form.isMarcarEntregue = !form.isMarcarEntregue;
              stepCtrl.formStream.update();
            },
          ),
          const Divider(height: 28),
          _switchOption(
            icon: Icons.calendar_today_outlined,
            label: 'Aceitar pedidos sem data de entrega',
            description:
                'Pedidos sem data de entrega só podem ENTRAR nesta etapa se esta opção estiver ativa.',
            value: form.isAcceptSemDataEntrega,
            onChanged: (_) {
              form.isAcceptSemDataEntrega = !form.isAcceptSemDataEntrega;
              stepCtrl.formStream.update();
            },
          ),
          const Divider(height: 28),
          _switchOption(
            icon: Icons.request_quote_outlined,
            label: 'Aceitar pedidos sem pedido financeiro',
            description:
                'Pedidos sem pedido financeiro preenchido só podem ENTRAR nesta etapa se esta opção estiver ativa.',
            value: form.isAcceptSemPedidoFinanceiro,
            onChanged: (_) {
              form.isAcceptSemPedidoFinanceiro =
                  !form.isAcceptSemPedidoFinanceiro;
              stepCtrl.formStream.update();
            },
          ),
        ]),
      ];

  // ─────────────────────────────────────────────────────────
  // HELPERS DE UI
  // ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryMain.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryMain),
        ),
        const SizedBox(width: 12),
        Text(title, style: AppCss.largeBold.setColor(AppColors.primaryMain)),
      ],
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutralLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(label, style: AppCss.smallBold.setColor(AppColors.neutralDark));
  }

  Widget _switchOption({
    required IconData icon,
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: value
                ? AppColors.secondary.withValues(alpha: 0.1)
                : AppColors.neutralLightest,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon,
              size: 18,
              color: value ? AppColors.secondary : AppColors.neutralMedium),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppCss.smallBold.setColor(
                      value ? AppColors.black : AppColors.neutralDark)),
              const SizedBox(height: 2),
              Text(description,
                  style:
                      AppCss.minimumRegular.setColor(AppColors.neutralMedium)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.secondary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _infoBox({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppCss.minimumRegular.setColor(AppColors.secondaryDark)),
          ),
        ],
      ),
    );
  }
}
