import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_tipo_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_color_picker.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/cadastro/cadastro_form.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/step/step_controller.dart';
import 'package:aco_plus/app/modules/step/step_shipping_view_model.dart';
import 'package:aco_plus/app/modules/step/step_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class StepCreatePage extends StatefulWidget {
  final StepModel? step;
  const StepCreatePage({this.step, super.key});

  @override
  State<StepCreatePage> createState() => _StepCreatePageState();
}

class _StepCreatePageState extends State<StepCreatePage> {
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

  Future<bool> _podeSair() async {
    final isDirty = _snapshot(stepCtrl.form) != _initialSnapshot;
    if (!isDirty) return true;
    return await showConfirmDialog(
      'Deseja realmente sair?',
      widget.step != null
          ? 'A edição que realizou será perdida'
          : 'Os dados da etapa serão perdidos.',
    );
  }

  Future<void> _voltar() async {
    if (await _podeSair() && mounted) pop(context);
  }

  void _atualizar() => stepCtrl.formStream.update();

  @override
  Widget build(BuildContext context) {
    return StreamOut(
      stream: stepCtrl.formStream.listen,
      builder: (_, form) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await _voltar();
        },
        child: CadastroFormPage(
          titulo: form.isEdit
              ? (form.name.text.trim().isEmpty ? 'Etapa' : form.name.text.trim())
              : 'Nova etapa',
          onVoltar: _voltar,
          onSalvar: () => stepCtrl.onConfirm(context, widget.step),
          onExcluir: form.isEdit
              ? () => stepCtrl.onDelete(context, widget.step!)
              : null,
          rotuloExcluir: 'Excluir etapa',
          secoes: [
            _identificacao(form),
            _fluxo(form),
            _entrada(form),
            _comportamento(form),
            _indicadores(form),
            _acompanhamento(form),
          ],
        ),
      ),
    );
  }

  // ── Nome e cor (com prévia do selo) ──────────────────────────────────────
  Widget _identificacao(StepCreateModel form) {
    return CadastroSecao(
      icon: Symbols.view_kanban,
      titulo: 'Identificação',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            label: 'Nome da etapa',
            controller: form.name,
            hint: 'Ex.: Corte, Dobra, Armação',
            onChanged: (_) => _atualizar(),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppColorPicker(
                  label: 'Cor:',
                  color: form.color,
                  onChanged: (e) {
                    form.color = e;
                    _atualizar();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Como aparece',
                      style: AppCss.minimumRegular
                          .setSize(12)
                          .setColor(AppColors.neutralMedium)),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: form.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      form.name.text.isEmpty ? 'Etapa' : form.name.text,
                      style: TextStyle(
                        color: form.color.computeLuminance() > 0.6
                            ? Colors.black
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── De onde vem e quem move ──────────────────────────────────────────────
  Widget _fluxo(StepCreateModel form) {
    return CadastroSecao(
      icon: Symbols.account_tree,
      titulo: 'Fluxo e permissão',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropDownList<StepModel>(
            label: 'Recebe pedidos das etapas',
            addeds: form.fromSteps,
            itens: FirestoreClient.steps.data
                .where((e) => e.id != form.id)
                .toList(),
            itemLabel: (e) => e.name,
            onChanged: () => stepCtrl.formStream.add(form),
          ),
          const SizedBox(height: 14),
          AppDropDownList<UsuarioTipoModel>(
            label: 'Quem pode mover pedidos para esta etapa',
            addeds: form.addedTipos,
            itens: AppSupabaseClient.usuarioTipos.data,
            itemLabel: (e) => e.nome,
            onChanged: () {
              form.moveRoles = form.addedTipos.map((t) => t.id).toList();
              _atualizar();
            },
          ),
          if (form.addedTipos.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nenhum perfil escolhido: todos os usuários podem mover pedidos para esta etapa.',
              style: AppCss.minimumRegular
                  .setSize(12.5)
                  .setColor(AppColors.neutralMedium),
            ),
          ],
        ],
      ),
    );
  }

  // ── Condições para o pedido ENTRAR ───────────────────────────────────────
  Widget _entrada(StepCreateModel form) {
    return CadastroSecao(
      icon: Symbols.login,
      titulo: 'Condições para entrar',
      apoio: 'Desligado = o pedido nessa situação não entra na etapa',
      child: Column(
        children: [
          CadastroOpcao(
            titulo: 'Aceita pedido sem elementos cadastrados',
            explicacao: 'Vale para pedidos CD e CDA',
            valor: form.isAcceptWithoutElements,
            onChanged: (v) {
              form.isAcceptWithoutElements = v;
              _atualizar();
            },
          ),
          CadastroOpcao(
            titulo: 'Aceita pedido sem endereço na obra',
            explicacao: 'Obra sem endereço nem coordenadas cadastrados',
            valor: form.isAcceptSemEndereco,
            onChanged: (v) {
              form.isAcceptSemEndereco = v;
              _atualizar();
            },
          ),
          CadastroOpcao(
            titulo: 'Aceita pedido sem data de entrega',
            valor: form.isAcceptSemDataEntrega,
            onChanged: (v) {
              form.isAcceptSemDataEntrega = v;
              _atualizar();
            },
          ),
          CadastroOpcao(
            titulo: 'Aceita pedido sem pedido financeiro',
            valor: form.isAcceptSemPedidoFinanceiro,
            onChanged: (v) {
              form.isAcceptSemPedidoFinanceiro = v;
              _atualizar();
            },
          ),
        ],
      ),
    );
  }

  // ── O que acontece com o pedido nesta etapa ──────────────────────────────
  Widget _comportamento(StepCreateModel form) {
    return CadastroSecao(
      icon: Symbols.tune,
      titulo: 'Nesta etapa',
      child: Column(
        children: [
          CadastroOpcao(
            titulo: 'Permite produção',
            explicacao: 'Os pedidos daqui podem entrar em ordens de produção',
            valor: form.isPermiteProducao,
            onChanged: (v) {
              form.isPermiteProducao = v;
              _atualizar();
            },
          ),
          CadastroOpcao(
            titulo: 'Aparece na tela de armação',
            explicacao: 'Os pedidos daqui aparecem para o armador',
            valor: form.isExibirArmacao,
            onChanged: (v) {
              form.isExibirArmacao = v;
              _atualizar();
            },
          ),
          CadastroOpcao(
            titulo: 'Gráfico da armação nos cartões',
            explicacao: 'Mostra o progresso da armação nos cartões do Kanban',
            valor: form.isExibirGraficoCDA,
            onChanged: (v) {
              form.isExibirGraficoCDA = v;
              _atualizar();
            },
          ),
          CadastroOpcao(
            titulo: 'Marca o pedido como entregue',
            explicacao:
                'Ao entrar aqui o pedido conta como entregue; ao sair, deixa de contar',
            valor: form.isMarcarEntregue,
            onChanged: (v) {
              form.isMarcarEntregue = v;
              _atualizar();
            },
          ),
          CadastroOpcao(
            titulo: 'Permite arquivar',
            explicacao: 'Os pedidos daqui podem ser arquivados',
            valor: form.isArchivedAvailable,
            onChanged: (v) {
              form.isArchivedAvailable = v;
              _atualizar();
            },
          ),
        ],
      ),
    );
  }

  // ── Onde a etapa entra nos números ───────────────────────────────────────
  Widget _indicadores(StepCreateModel form) {
    return CadastroSecao(
      icon: Symbols.monitoring,
      titulo: 'Indicadores',
      child: Column(
        children: [
          CadastroOpcao(
            titulo: 'Conta no "Total em produção"',
            explicacao: 'Soma os pedidos daqui no quadro da Gestão à Vista',
            valor: form.isConsiderarTotalProducao,
            onChanged: (v) {
              form.isConsiderarTotalProducao = v;
              _atualizar();
            },
          ),
          CadastroOpcao(
            titulo: 'Conta no consumo de matéria-prima',
            explicacao: 'Considera os pedidos daqui no relatório de consumo',
            valor: form.considerarConsumoRelatorioPedidos,
            onChanged: (v) {
              form.considerarConsumoRelatorioPedidos = v;
              _atualizar();
            },
          ),
        ],
      ),
    );
  }

  // ── Mensagem para o cliente acompanhar o pedido ──────────────────────────
  Widget _acompanhamento(StepCreateModel form) {
    return CadastroSecao(
      icon: Symbols.local_shipping,
      titulo: 'Acompanhamento do cliente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CadastroOpcao(
            titulo: 'Aparece para o cliente',
            explicacao:
                'O cliente vê esta etapa na página de acompanhamento do pedido',
            valor: form.isShipping,
            onChanged: (v) {
              form.isShipping = v;
              form.shipping = v ? StepShippingCreateModel() : null;
              _atualizar();
            },
          ),
          if (form.isShipping && form.shipping != null) ...[
            const SizedBox(height: 10),
            AppField(
              label: 'Mensagem para o cliente',
              required: false,
              controller: form.shipping!.description,
              hint: 'Ex.: Seu pedido está em fase de corte',
              maxLines: 3,
              onChanged: (_) => _atualizar(),
            ),
          ],
        ],
      ),
    );
  }
}
