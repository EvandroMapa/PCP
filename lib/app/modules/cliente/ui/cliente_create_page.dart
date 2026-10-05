import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';

import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
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
import 'package:material_symbols_icons/symbols.dart';

class ClienteCreatePage extends StatefulWidget {
  final ClienteModel? cliente;
  final bool isFromOrder;
  const ClienteCreatePage({this.cliente, this.isFromOrder = false, super.key});

  @override
  State<ClienteCreatePage> createState() => _ClienteCreatePageState();
}

class _ClienteCreatePageState extends State<ClienteCreatePage>
    with SingleTickerProviderStateMixin {
  late final TabController _abas = TabController(length: 2, vsync: this);
  String _initialSnapshot = '';
  bool _clienteSalvo = false;
  bool _salvando = false;

  String _snapshot(ClienteCreateModel form) =>
      '${form.nome.text}|${form.telefone.text}|${form.cpf.text}';

  bool get _isDirty => _snapshot(clienteCtrl.form) != _initialSnapshot;

  bool get _obrasBlockedByDirty =>
      _isDirty || (!clienteCtrl.form.isEdit && !_clienteSalvo);

  bool get _podeSalvar =>
      (widget.cliente != null &&
          usuario.permission.cliente.contains(UserPermissionType.update)) ||
      (widget.cliente == null &&
          usuario.permission.cliente.contains(UserPermissionType.create));

  @override
  void initState() {
    setWebTitle(widget.cliente != null ? 'Editar Cliente' : 'Novo Cliente');
    _abas.addListener(() => setState(() {}));

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
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await clienteCtrl.onConfirm(context, widget.cliente, widget.isFromOrder);
      if (mounted) {
        _initialSnapshot = _snapshot(clienteCtrl.form);
        _clienteSalvo = true;
      }
    } catch (_) {}
    if (mounted) setState(() => _salvando = false);
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
        titleSpacing: 0,
        title: StreamOut(
          stream: clienteCtrl.formStream.listen,
          builder: (_, form) => Row(
            children: [
              Flexible(
                child: Text(
                  form.isEdit
                      ? (form.nome.text.trim().isEmpty
                          ? 'Cliente'
                          : form.nome.text.trim())
                      : 'Novo cliente',
                  overflow: TextOverflow.ellipsis,
                  style: AppCss.largeBold.setColor(AppColors.white).setSize(18),
                ),
              ),
              if (form.isEdit) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Cód. ${form.codigo}',
                    style: AppCss.minimumBold
                        .setSize(11)
                        .setColor(AppColors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_podeSalvar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.white,
                  foregroundColor: AppColors.primaryMain,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: AppCss.minimumBold.setSize(13),
                ),
                onPressed: _salvando ? null : _salvar,
                icon: _salvando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 18),
                label: const Text('Salvar'),
              ),
            ),
          // Excluir longe de um clique acidental
          if (clienteCtrl.form.isEdit &&
              usuario.permission.cliente.contains(UserPermissionType.delete))
            PopupMenuButton<String>(
              tooltip: 'Mais ações',
              icon: Icon(Icons.more_vert, color: AppColors.white),
              onSelected: (_) => clienteCtrl.onDelete(context, widget.cliente!),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'excluir',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Text('Excluir cliente',
                        style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: clienteCtrl.formStream.listen,
        builder: (_, form) => Column(
          children: [
            _barraAbas(form),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: _abas.index == 0
                          ? _buildDados(form)
                          : _buildObras(form),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Abas (mesmo padrão do pedido) ──────────────────────────────────────────

  Widget _barraAbas(ClienteCreateModel form) {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.neutralLight)),
      ),
      child: TabBar(
        controller: _abas,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: AppCss.minimumBold.setSize(13.5),
        unselectedLabelStyle: AppCss.minimumBold.setSize(13.5),
        labelColor: AppColors.black,
        unselectedLabelColor: AppColors.neutralMedium,
        indicatorColor: AppColors.brand,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: [
          _aba(Symbols.badge, 'Dados'),
          _aba(Symbols.apartment, 'Obras', form.obras.length),
        ],
      ),
    );
  }

  Tab _aba(IconData icon, String label, [int? count]) => Tab(
        height: 46,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Text(label),
            if (count != null) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.neutralLightest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: AppCss.minimumBold
                      .setSize(11)
                      .setColor(AppColors.neutralDark),
                ),
              ),
            ],
          ],
        ),
      );

  // ── Cartão de seção ────────────────────────────────────────────────────────

  Widget _secao({
    required IconData icon,
    required String titulo,
    Widget? acao,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.neutralLightest)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.neutralMedium),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(titulo, style: AppCss.minimumBold.setSize(14)),
                ),
                if (acao != null) acao,
              ],
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  // ── Dados ──────────────────────────────────────────────────────────────────

  Widget _buildDados(ClienteCreateModel form) {
    final nome = AppField(
      label: 'Nome',
      controller: form.nome,
      onChanged: (_) => clienteCtrl.formStream.update(),
    );
    final telefone = AppField(
      label: 'Telefone',
      hint: '(00) 00000-0000',
      controller: form.telefone,
      onChanged: (_) => clienteCtrl.formStream.update(),
    );
    final documento = AppField(
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
    );

    return _secao(
      icon: Symbols.badge,
      titulo: 'Identificação',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largo = constraints.maxWidth >= 560;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              nome,
              const SizedBox(height: 14),
              if (largo)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: telefone),
                    const SizedBox(width: 12),
                    Expanded(child: documento),
                  ],
                )
              else ...[
                telefone,
                const SizedBox(height: 14),
                documento,
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Obras ──────────────────────────────────────────────────────────────────

  Future<void> _novaObra(ClienteCreateModel form) async {
    // A obra é gravada pelo ObraController; aqui só refletimos na lista
    final obra = await push(
      context,
      ObraCreatePage(endereco: form.endereco, clienteId: form.id),
    );
    if (obra is ObraModel) {
      form.obras.add(obra);
      clienteCtrl.formStream.update();
    }
  }

  Future<void> _abrirObra(ClienteCreateModel form, ObraModel obraForm) async {
    // O ObraController já persiste a edição/exclusão via clienteId.
    final obra = await push(
      context,
      ObraCreatePage(obra: obraForm, clienteId: form.id),
    ) as ObraModel?;
    if (obra == null) return;
    final idx = form.obras.map((e) => e.id).toList().indexOf(obraForm.id);
    if (idx < 0) return;
    if (obra.id != 'delete') {
      form.obras[idx] = obra;
    } else {
      form.obras.removeAt(idx);
    }
    clienteCtrl.formStream.update();
  }

  Widget _buildObras(ClienteCreateModel form) {
    final bloqueado = _obrasBlockedByDirty;
    return _secao(
      icon: Symbols.apartment,
      titulo: 'Obras (${form.obras.length})',
      padding: EdgeInsets.zero,
      acao: bloqueado
          ? null
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                side: BorderSide(color: AppColors.neutralLight),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _novaObra(form),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nova obra'),
            ),
      child: bloqueado
          ? _aviso(
              Icons.info_outline,
              _isDirty
                  ? 'Salve as alterações do cliente antes de mexer nas obras.'
                  : 'Salve o cliente para cadastrar obras.',
            )
          : form.obras.isEmpty
              ? _aviso(Symbols.apartment, 'Nenhuma obra cadastrada.')
              : Column(
                  children: [
                    for (final obra in form.obras) _linhaObra(form, obra),
                  ],
                ),
    );
  }

  Widget _aviso(IconData icon, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.neutralMedium),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: AppCss.minimumRegular
                  .setSize(13.5)
                  .setColor(AppColors.neutralDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaObra(ClienteCreateModel form, ObraModel obra) {
    final end = obra.endereco;
    final cidade = end == null
        ? ''
        : [end.localidade, end.estado]
            .where((e) => e.trim().isNotEmpty)
            .join(' / ');
    final cor = obra.status.color;
    return InkWell(
      onTap: () => _abrirObra(form, obra),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.neutralLightest)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(obra.descricao, style: AppCss.minimumBold.setSize(14)),
                  if (cidade.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      cidade,
                      style: AppCss.minimumRegular
                          .setSize(12.5)
                          .setColor(AppColors.neutralMedium),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                obra.status.label,
                style: AppCss.minimumBold.setSize(11.5).setColor(cor),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: AppColors.neutralMedium),
          ],
        ),
      ),
    );
  }
}
