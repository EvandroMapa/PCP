import 'package:aco_plus/app/core/client/firestore/collections/checklist/models/checklist_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_checkbox.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_drop_down_list.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/date_picker_field.dart';
import 'package:aco_plus/app/core/components/done_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/enums/obra_status.dart';
import 'package:aco_plus/app/core/formatters/uper_case_formatter.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/cliente/ui/cliente_create_simplify_bottom.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_order_edit_bottom.dart';
import 'package:aco_plus/app/modules/pedido/view_models/pedido_produto_view_model.dart';
import 'package:aco_plus/app/core/extensions/text_controller_ext.dart';
import 'package:aco_plus/app/modules/pedido/view_models/pedido_view_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:flutter/material.dart';

class PedidoCreatePage extends StatefulWidget {
  final PedidoModel? pedido;
  final PedidoModel? pai;
  const PedidoCreatePage({this.pedido, this.pai, super.key});

  @override
  State<PedidoCreatePage> createState() => _PedidoCreatePageState();
}

class _PedidoCreatePageState extends State<PedidoCreatePage> {
  int _selected = 0;
  String _initialSnapshot = '';

  String _snapshot(PedidoCreateModel form) {
    return '${form.tipo?.name}|${form.localizador.text}|${form.planilhamento.text}|'
        '${form.romaneio.text}|${form.descricao.text}|${form.cliente?.id}|'
        '${form.obra?.id}|${form.checklist?.id}|${form.deliveryAt?.millisecondsSinceEpoch}|'
        '${form.produtos.length}';
  }

  @override
  void initState() {
    setWebTitle('Novo Pedido');
    pedidoCtrl.onInitCreatePage(widget.pedido, widget.pai);
    _initialSnapshot = _snapshot(pedidoCtrl.form);
    super.initState();
  }

  String _getTitle(PedidoCreateModel form) {
    if (widget.pai != null) {
      return form.isEdit ? 'Editar Parcial' : 'Novo Parcial';
    }
    return form.isEdit ? 'Editar Pedido' : 'Novo Pedido';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            final isDirty = _snapshot(pedidoCtrl.form) != _initialSnapshot;
            if (isDirty) {
              final confirm = await showConfirmDialog(
                'Deseja realmente sair?',
                'Os dados do pedido serão perdidos.',
              );
              if (confirm && context.mounted) {
                pop(context);
              }
            } else {
              pop(context);
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          pedidoCtrl.formStream.hasValue
              ? _getTitle(pedidoCtrl.form)
              : 'Adicionar Pedido',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          if ((widget.pedido != null &&
                  usuario.permission.pedido
                      .contains(UserPermissionType.update)) ||
              (widget.pedido == null &&
                  usuario.permission.pedido
                      .contains(UserPermissionType.create)))
            IconLoadingButton(
              () async =>
                  await pedidoCtrl.onConfirm(context, widget.pedido, false),
            ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: pedidoCtrl.formStream.listen,
        builder: (_, form) => Row(
          children: [
            _sidebar(form),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_selected),
                  child: _sectionContent(form),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebar(PedidoCreateModel form) {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border(right: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Preview Pedido
          Tooltip(
            message: form.localizador.text.isEmpty
                ? 'Novo Pedido'
                : form.localizador.text,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryMain,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryMain.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  form.localizador.text.isNotEmpty
                      ? form.localizador.text.substring(0, 1).toUpperCase()
                      : 'P',
                  style:
                      AppCss.minimumBold.setColor(AppColors.white).setSize(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sidebarItem(0, Icons.info_outline, 'Dados Gerais'),
          if (form.tipo != PedidoTipo.outros)
            _sidebarItem(1, Icons.inventory_2_outlined, 'Produtos'),
          const Spacer(),
          if (widget.pedido != null &&
              usuario.permission.pedido.contains(UserPermissionType.delete))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Tooltip(
                message: 'Excluir Pedido',
                preferBelow: false,
                child: InkWell(
                  onTap: () => pedidoCtrl.onDelete(context, widget.pedido!),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label) {
    final isSelected = _selected == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Tooltip(
        message: label,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: () {
            setState(() => _selected = index);
            if (index == 1) {
              Future.delayed(const Duration(milliseconds: 300), () {
                pedidoCtrl.form.produto.produtoEC.focus.requestFocus();
              });
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryMain.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(
                      color: AppColors.primaryMain.withValues(alpha: 0.2))
                  : null,
            ),
            child: Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primaryMain : Colors.grey[400],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionContent(PedidoCreateModel form) {
    if (_selected == 0) return _dadosGeraisSection(form);
    return _produtosSection(form);
  }

  Widget _dadosGeraisSection(PedidoCreateModel form) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionPanel(
          icon: Icons.info_outline,
          title: 'INFORMAÇÕES PRINCIPAIS',
          children: [
            AppDropDown<PedidoTipo?>(
              label: 'Tipo',
              item: form.tipo,
              itens: PedidoTipo.values,
              itemLabel: (e) => e!.label,
              onSelect: (e) async {
                if (e == PedidoTipo.outros && form.produtos.isNotEmpty) {
                  final confirm = await showConfirmDialog(
                    'Alterar para Outros?',
                    'A lista de produtos será limpa. Deseja continuar?',
                  );
                  if (!confirm) {
                    pedidoCtrl.formStream.update();
                    return;
                  }
                  form.produtos.clear();
                }

                form.tipo = e;
                if (e == PedidoTipo.outros) {
                  _selected = 0;
                } else {
                  form.tags.clear();
                }
                pedidoCtrl.formStream.update();
              },
            ),
            if (form.tipo == PedidoTipo.outros) ...[
              const H(16),
              AppDropDownList<TagModel>(
                label: 'Etiquetas *',
                addeds: form.tags,
                itens: FirestoreClient.tags.data.cast<TagModel>(),
                itemLabel: (TagModel e) => e.nome,
                onChanged: () => pedidoCtrl.formStream.update(),
              ),
            ],
            const H(16),
            if (widget.pai != null) ...[
              AppField(
                label: 'Pedido Total',
                controller: TextController(text: widget.pai?.localizador),
                isDisable: true,
              ),
              const H(16),
            ],
            AppField(
              label: 'Localizador',
              inputFormatters: [UpperCaseFormatter()],
              capitalization: TextCapitalization.characters,
              controller: form.localizador,
              type: TextInputType.name,
              onChanged: (_) => pedidoCtrl.formStream.update(),
            ),
            const H(16),
            Row(
              children: [
                Expanded(
                  child: AppField(
                    label: 'Planilhamento',
                    controller: form.planilhamento,
                    onChanged: (_) => pedidoCtrl.formStream.update(),
                  ),
                ),
                const W(16),
                Expanded(
                  child: AppField(
                    label: 'Romaneio',
                    controller: form.romaneio,
                    onChanged: (_) => pedidoCtrl.formStream.update(),
                  ),
                ),
              ],
            ),
            const H(16),
            AppField(
              label: 'Descrição',
              controller: form.descricao,
              onChanged: (_) => pedidoCtrl.formStream.update(),
            ),
          ],
        ),
        const H(24),
        _sectionPanel(
          icon: Icons.business_outlined,
          title: 'CLIENTE E OBRA',
          children: [
            AppDropDown<ClienteModel?>(
              hasFilter: true,
              label: 'Cliente',
              disable: widget.pai != null || form.isPartial,
              item: form.cliente,
              itens: FirestoreClient.clientes.data,
              onCreated: () async {
                ClienteModel? created = await showClienteCreateSimplifyBottom();
                if (created == null) return null;
                final cliente = FirestoreClient.clientes.data.firstWhere(
                    (e) => e.id == created.id,
                    orElse: () => created);
                form.cliente = cliente;
                form.obra = cliente.obras.firstOrNull;
                pedidoCtrl.formStream.update();
                return cliente;
              },
              itemLabel: (e) => e!.nome,
              onSelect: (e) async {
                if (form.cliente?.id != e?.id) {
                  form.cliente = e;
                  form.obra = null;
                }
                pedidoCtrl.formStream.update();
              },
            ),
            const H(16),
            AppDropDown<ObraModel?>(
              label: 'Obra',
              item: form.obra,
              disable: form.cliente == null || widget.pai != null || form.isPartial,
              itens: form.cliente?.obras
                      .where((e) => e.status == ObraStatus.emAndamento)
                      .toList() ??
                  [],
              itemLabel: (e) => e != null
                  ? '${e.descricao} - ${e.endereco?.localidade ?? ''}'
                  : 'Selecione',
              onSelect: (e) {
                form.obra = e;
                pedidoCtrl.formStream.update();
              },
            ),
          ],
        ),
        const H(24),
        _sectionPanel(
          icon: Icons.settings_outlined,
          title: 'CONFIGURAÇÕES E DATAS',
          children: [
            AppDropDown<ChecklistModel?>(
              label: 'Modelo de checklist',
              hasFilter: true,
              item: form.checklist,
              itens: FirestoreClient.checklists.data,
              itemLabel: (e) => e!.nome,
              onSelect: (e) {
                form.checklist = e;
                pedidoCtrl.formStream.update();
              },
            ),
            if (widget.pedido == null) ...[
              const H(16),
              AppDropDown<StepModel?>(
                label: 'Etapa Inicial',
                item: form.step,
                itens: FirestoreClient.steps.data,
                itemLabel: (e) => e?.name ?? 'Selecione',
                onSelect: (e) {
                  form.step = e!;
                  pedidoCtrl.formStream.update();
                },
              ),
            ],
            const H(16),
            DatePickerField(
              required: false,
              label: 'Previsão de Entrega',
              item: form.deliveryAt,
              onChanged: (value) {
                form.deliveryAt = value;
                pedidoCtrl.formStream.update();
              },
            ),
          ],
        ),
        const H(24),
        _sectionPanel(
          icon: Icons.payments_outlined,
          title: 'FINANCEIRO E LOGÍSTICA',
          children: [
            AppField(
              label: 'Pedido Financeiro',
              controller: form.pedidoFinanceiro,
              onChanged: (_) => pedidoCtrl.formStream.update(),
            ),
            const H(16),
            AppField(
              label: 'Instruções Financeiras',
              controller: form.instrucoesFinanceiras,
              onChanged: (_) => pedidoCtrl.formStream.update(),
            ),
            const H(16),
            AppField(
              label: 'Instruções de Entrega',
              controller: form.instrucoesEntrega,
              onChanged: (_) => pedidoCtrl.formStream.update(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _produtosSection(PedidoCreateModel form) {
    // ── Layout dedicado para criação de parcial ──
    if (widget.pai != null) {
      return _parcialProdutosSection(form);
    }
    return Column(
      children: [
        if (widget.pedido == null || widget.pedido!.pedidosFilhos.isEmpty)
          _produtoAddCard(form),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            itemCount: form.produtos.length,
            itemBuilder: (_, i) => _produtoItemCard(form, form.produtos[i], i),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── LAYOUT PARCIAL ── Seção dedicada para criação de pedidos parciais
  // ══════════════════════════════════════════════════════════════════════════
  Widget _parcialProdutosSection(PedidoCreateModel form) {
    final pai = widget.pai!;
    // Calcular total selecionado
    double totalSelecionado = 0;
    for (final p in form.produtos) {
      if (p.isSelected && p.qtde.text.isNotEmpty) {
        totalSelecionado += p.qtde.doubleValue.precision;
      }
    }
    totalSelecionado = totalSelecionado.precision;

    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.6,
        heightFactor: 0.8,
        child: Column(
      children: [
        // ── Header do Mestre ──
        Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E293B),
                const Color(0xFF334155),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_tree_outlined,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedidos Parciais',
                      style: AppCss.mediumBold
                          .setColor(Colors.white)
                          .setSize(13),
                    ),
                    Text(
                      pai.localizador,
                      style: AppCss.minimumRegular
                          .setColor(Colors.white.withValues(alpha: 0.7))
                          .setSize(11),
                    ),
                  ],
                ),
              ),
              // Botão PDF
              IconButton(
                onPressed: () =>
                    pedidoCtrl.onGeneratePDF(widget.pedido!),
                icon: const Icon(Icons.picture_as_pdf_outlined,
                    color: Colors.white, size: 20),
                tooltip: 'Relatório de Pedidos Parciais',
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalSelecionado > 0
                      ? AppColors.primaryMain.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${totalSelecionado.toKg()} selecionado',
                  style: AppCss.minimumBold.setColor(Colors.white).setSize(11),
                ),
              ),
              const SizedBox(width: 10),
              // Botão salvar com estado de loading
              _SaveParcialButton(
                totalSelecionado: totalSelecionado,
                pedido: widget.pedido,
              ),
            ],
          ),
        ),
        // ── Lista de Produtos ──
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: form.produtos.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey[100]),
                itemBuilder: (_, i) =>
                    _parcialProdutoRow(form, form.produtos[i]),
              ),
            ),
          ),
        ),
      ],
    ),
      ),
    );
  }

  Widget _parcialProdutoRow(
      PedidoCreateModel form, PedidoProdutoCreateModel produto) {
    final double disponivel = (produto.qtdeDisponivel ?? 0).precision;
    final double valor = produto.qtde.doubleValue.precision;
    final double saldoRestante = (disponivel - valor).precision;
    final bool excedeu = valor > disponivel;
    final bool desabilitado = !produto.isEnabled;

    // Cor do saldo
    Color saldoColor;
    if (excedeu) {
      saldoColor = AppColors.error;
    } else if (saldoRestante == 0 && disponivel > 0) {
      saldoColor = Colors.green[700]!;
    } else if (valor > 0) {
      saldoColor = AppColors.primaryMain;
    } else {
      saldoColor = Colors.grey[400]!;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: desabilitado
          ? Colors.grey[50]
          : valor > 0
              ? AppColors.primaryMain.withValues(alpha: 0.03)
              : Colors.white,
      child: Row(
        children: [
          // Checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: produto.isSelected,
              onChanged: desabilitado
                  ? null
                  : (v) {
                      produto.isSelected = v ?? false;
                      if (!produto.isSelected) {
                        produto.qtde.text = '0';
                      }
                      pedidoCtrl.formStream.update();
                    },
              activeColor: AppColors.primaryMain,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 12),
          // Produto info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produto.produtoModel?.descricao ?? '',
                  style: AppCss.mediumBold.setSize(13).setColor(
                        desabilitado ? Colors.grey[400]! : const Color(0xFF1E293B),
                      ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      'Disponível: ${disponivel.toKg()}',
                      style: AppCss.minimumRegular
                          .setSize(11)
                          .setColor(Colors.grey[500]!),
                    ),
                    if (desabilitado) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ESGOTADO',
                          style: AppCss.minimumBold
                              .setSize(9)
                              .setColor(AppColors.error),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Campo de quantidade inline
          SizedBox(
            width: 110,
            child: IgnorePointer(
              ignoring: desabilitado,
              child: Opacity(
                opacity: desabilitado ? 0.4 : 1.0,
                child: TextField(
                  controller: produto.qtde.controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: AppCss.mediumBold.setSize(14).setColor(
                        excedeu ? AppColors.error : const Color(0xFF1E293B),
                      ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    suffixText: 'Kg',
                    suffixStyle: AppCss.minimumRegular
                        .setSize(11)
                        .setColor(Colors.grey[400]!),
                    filled: true,
                    fillColor: desabilitado
                        ? Colors.grey[100]
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: const Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: valor > 0
                            ? AppColors.primaryMain.withValues(alpha: 0.3)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: excedeu
                            ? AppColors.error
                            : AppColors.primaryMain,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    produto.isSelected = produto.qtde.doubleValue > 0;
                    pedidoCtrl.formStream.update();
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Saldo remanescente
          SizedBox(
            width: 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Saldo',
                  style: AppCss.minimumRegular
                      .setSize(10)
                      .setColor(Colors.grey[400]!),
                ),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: AppCss.mediumBold
                      .setSize(13)
                      .setColor(saldoColor),
                  child: Text(saldoRestante.toKg()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _produtoAddCard(PedidoCreateModel form) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_circle_outline, color: AppColors.primaryMain),
              const SizedBox(width: 12),
              Text('ADICIONAR PRODUTO / BITOLA',
                  style: AppCss.mediumBold.setSize(14)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: AppDropDown<ProdutoModel?>(
                  label: 'Produto',
                  controller: form.produto.produtoEC,
                  nextFocus: form.produto.qtde.focus,
                  item: form.produto.produtoModel,
                  itens: FirestoreClient.produtos.data
                      .where((e) => !form.produtos
                          .map((e) => e.produtoModel?.id)
                          .contains(e.id))
                      .toList(),
                  itemLabel: (e) => e?.descricao ?? 'Selecione',
                  onSelect: (e) {
                    form.produto.produtoModel = e;
                    pedidoCtrl.formStream.update();
                  },
                ),
              ),
              const W(16),
              Expanded(
                flex: 2,
                child: AppField(
                  label: 'Quantidade',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  controller: form.produto.qtde,
                  action: TextInputAction.done,
                  suffixText: 'Kg',
                  onChanged: (_) => pedidoCtrl.formStream.update(),
                  onEditingComplete: () {
                    if (form.produto.isEnable) {
                      form.produtos.add(form.produto);
                      form.produto = PedidoProdutoCreateModel();
                      form.produto.produtoEC.focus.requestFocus();
                      pedidoCtrl.formStream.update();
                    }
                  },
                ),
              ),
              const W(16),
              IconButton(
                onPressed: !form.produto.isEnable
                    ? null
                    : () {
                        form.produtos.add(form.produto);
                        form.produto = PedidoProdutoCreateModel();
                        pedidoCtrl.formStream.update();
                      },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(form.produto.isEnable
                      ? AppColors.primaryMain
                      : Colors.grey[300]),
                  padding: WidgetStateProperty.all(const EdgeInsets.all(16)),
                  shape: WidgetStateProperty.all(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                ),
                icon: Icon(Icons.add, color: AppColors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _produtoItemCard(
      PedidoCreateModel form, PedidoProdutoCreateModel produto, int index) {
    bool isDisabled = !produto.isEnabled ||
        (form.isEdit &&
            FirestoreClient.ordens.data
                .expand((e) => e.produtos.map((e) => e.id))
                .any((e) => e == produto.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDisabled ? Colors.grey[200]! : Colors.grey[300]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: Center(
              child: Text('${index + 1}',
                  style: AppCss.minimumBold.setColor(AppColors.primaryMain))),
        ),
        title: Text(produto.produtoModel?.descricao ?? '',
            style: AppCss.mediumBold),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quantidade: ${double.tryParse(produto.qtde.text)?.toKg() ?? produto.qtde.text}',
                style: AppCss.minimumRegular),
            if (isDisabled)
              Text(
                !produto.isEnabled
                    ? 'Quantidade já direcionada'
                    : 'Produto vinculado a Ordem',
                style: AppCss.minimumBold.setColor(AppColors.error).setSize(11),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDisabled) ...[
              IconButton(
                onPressed: () async {
                  // Mestre não pode alterar quantidade — parciais dependem do original
                  if (widget.pedido != null &&
                      widget.pedido!.pedidosFilhos.isNotEmpty) {
                    NotificationService.showNegative(
                      'Edição bloqueada',
                      'Este pedido possui parciais vinculados. '
                      'A quantidade original não pode ser alterada.',
                    );
                    return;
                  }
                  final qtde = await showPedidoOrderEditBottom(
                      produto, produto.qtdeDisponivel);
                  if (qtde != null) {
                    produto.qtde.text = qtde.toString();
                    pedidoCtrl.formStream.update();
                  }
                },
                icon: Icon(Icons.edit_outlined,
                    color: Colors.blue[700], size: 20),
              ),
              if (widget.pai == null &&
                  (widget.pedido == null ||
                      widget.pedido!.pedidosFilhos.isEmpty))
                IconButton(
                  onPressed: () async {
                    if (await showConfirmDialog('Remover Produto',
                        'Deseja remover ${produto.produtoModel?.descricao}?')) {
                      form.produtos.remove(produto);
                      pedidoCtrl.formStream.update();
                    }
                  },
                  icon: Icon(Icons.delete_outline,
                      color: AppColors.error, size: 20),
                ),
              if (widget.pai != null)
                AppCheckbox(
                  value: produto.isSelected,
                  onChanged: (value) {
                    produto.isSelected = value;
                    pedidoCtrl.formStream.update();
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionPanel(
      {required IconData icon,
      required String title,
      required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryMain, size: 20),
              const SizedBox(width: 12),
              Text(title,
                  style: AppCss.mediumBold
                      .setSize(13)
                      .setColor(Colors.grey[700]!)),
            ],
          ),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _SaveParcialButton extends StatefulWidget {
  final double totalSelecionado;
  final PedidoModel? pedido;
  
  const _SaveParcialButton({
    required this.totalSelecionado,
    required this.pedido,
  });

  @override
  State<_SaveParcialButton> createState() => _SaveParcialButtonState();
}

class _SaveParcialButtonState extends State<_SaveParcialButton> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.totalSelecionado > 0;
    
    return InkWell(
      onTap: enabled && !isLoading
          ? () async {
              setState(() => isLoading = true);
              try {
                await pedidoCtrl.onConfirm(context, widget.pedido, false);
              } finally {
                if (mounted) setState(() => isLoading = false);
              }
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.green.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                Icons.check,
                size: 18,
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
              ),
      ),
    );
  }
}
