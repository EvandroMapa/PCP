import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_model.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_controller.dart';
import 'package:aco_plus/app/modules/pedido_compra/pedido_compra_view_model.dart';
import 'package:aco_plus/app/modules/pedido_compra/ui/pedido_compra_planilha_page.dart';
import 'package:aco_plus/app/modules/pedido_compra/ui/simulador_compra_page.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:flutter/material.dart';

class PedidoCompraPage extends StatefulWidget {
  final bool standalone;
  const PedidoCompraPage({super.key, this.standalone = false});

  @override
  State<PedidoCompraPage> createState() => _PedidoCompraPageState();
}

class _PedidoCompraPageState extends State<PedidoCompraPage> {
  @override
  void initState() {
    setWebTitle('Pedidos de Compra');
    pedidoCompraCtrl.onInit();
    super.initState();
    if (!widget.standalone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        baseCtrl.appBarActionsStream.add([
          Tooltip(
            message: 'Montar sugestão de compra',
            preferBelow: false,
            child: IconButton(
              icon: const Icon(Icons.auto_graph_rounded, size: 20),
              color: Colors.white,
              onPressed: () => push(const SimuladorCompraPage()),
            ),
          ),
          Tooltip(
            message: 'Novo pedido de compra',
            preferBelow: false,
            child: IconButton(
              icon: const Icon(Icons.add, size: 20),
              color: Colors.white,
              onPressed: () {
                pedidoCompraCtrl.iniciarPlanilha();
                push(const PedidoCompraPlanilhaPage());
              },
            ),
          ),
        ]);
      });
    }
  }

  @override
  void dispose() {
    if (!widget.standalone) {
      baseCtrl.appBarActionsStream.add([]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.standalone) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pedidos de Compra',
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.primaryMain,
          actions: [_btnNovo(context)],
        ),
        body: _body(context),
      );
    }
    return _body(context);
  }

  Widget _body(BuildContext context) {
    return StreamOut<List<PedidoCompraModel>>(
      stream: BackendClient.pedidosCompra.dataStream.listen,
      builder: (_, __) => _lista(context),
    );
  }

  Widget _lista(BuildContext context) {
    return StreamOut<bool>(
      stream: pedidoCompraCtrl.showEfetivadosStream.listen,
      builder: (_, showHistorico) {
        final ativos = BackendClient.pedidosCompra.ativosAgrupados;
        final efetivados = BackendClient.pedidosCompra.efetivadosAgrupados;
        // Conta GRUPOS (orçamentos), não itens individuais
        final gruposPendentes = ativos.values.where((g) => g.first.isPendente).toList();
        final gruposConfirmados = ativos.values.where((g) => g.first.isConfirmado).toList();
        final totalOrcamentos = gruposPendentes.length;
        final totalItensPendentes = gruposPendentes.fold<int>(0, (s, g) => s + g.length);
        final totalConfirmados = gruposConfirmados.length;
        final totalItensConfirmados = gruposConfirmados.fold<int>(0, (s, g) => s + g.length);

        return Column(
          children: [
            _header(context, totalOrcamentos, totalItensPendentes, totalConfirmados, totalItensConfirmados, showHistorico),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: showHistorico
                    ? _viewEfetivados(efetivados)
                    : _viewAtivos(context, ativos),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _viewAtivos(
      BuildContext context,
      Map<String, List<PedidoCompraModel>> ativos) {
    if (ativos.isEmpty) {
      return const Padding(
        key: ValueKey('ativos-empty'),
        padding: EdgeInsets.only(top: 60),
        child: EmptyData(message: 'Nenhum pedido de compra ativo'),
      );
    }
    return ListView(
      key: const ValueKey('ativos-list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        ...ativos.entries.map((e) => _cardGrupoAtivo(context, e.value)),
      ],
    );
  }

  Widget _viewEfetivados(
      Map<String, List<PedidoCompraModel>> efetivados) {
    if (efetivados.isEmpty) {
      return const Padding(
        key: ValueKey('efetivados-empty'),
        padding: EdgeInsets.only(top: 60),
        child: EmptyData(message: 'Nenhum pedido efetivado ainda'),
      );
    }
    return ListView(
      key: const ValueKey('efetivados-list'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        ...efetivados.entries.map((e) => _cardGrupoEfetivado(e.value)),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header(BuildContext context, int totalOrcamentos, int totalItensPendentes,
      int totalConfirmados, int totalItensConfirmados, bool showHistorico) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      color: Colors.white,
      child: Row(
        children: [
          if (!showHistorico) ...[
            if (totalOrcamentos > 0)
              _miniChip(
                  '$totalOrcamentos orçamento${totalOrcamentos > 1 ? 's' : ''} · $totalItensPendentes ${totalItensPendentes > 1 ? 'itens' : 'item'}',
                  Colors.orange[700]!),
            if (totalConfirmados > 0) ...[
              const SizedBox(width: 4),
              _miniChip(
                  '$totalConfirmados confirmado${totalConfirmados > 1 ? 's' : ''} · $totalItensConfirmados ${totalItensConfirmados > 1 ? 'itens' : 'item'}',
                  Colors.blue[700]!),
            ],
          ],
          const Spacer(),
          // Toggle histórico / ativos
          Tooltip(
            message: showHistorico
                ? 'Ver pedidos ativos'
                : 'Ver pedidos efetivados',
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 300),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => pedidoCompraCtrl.showEfetivadosStream
                  .add(!showHistorico),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: showHistorico
                      ? Colors.green.withValues(alpha: 0.10)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: showHistorico
                        ? Colors.green.withValues(alpha: 0.20)
                        : Colors.grey.withValues(alpha: 0.15),
                  ),
                ),
                child: Icon(
                  showHistorico
                      ? Icons.shopping_cart_outlined
                      : Icons.history,
                  size: 18,
                  color: showHistorico
                      ? Colors.green[700]
                      : Colors.grey[400],
                ),
              ),
            ),
          ),
          if (widget.standalone && !showHistorico) ...[
            const SizedBox(width: 8),
            _btnSimulador(context),
            const SizedBox(width: 8),
            _btnNovo(context),
          ],
        ],
      ),
    );
  }

  Widget _miniChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style:
                AppCss.minimumBold.setColor(color).setSize(10)),
      );

  Widget _btnSimulador(BuildContext context) => Tooltip(
        message: 'Montar sugestão de compra',
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => push(context, const SimuladorCompraPage()),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.primaryMain.withValues(alpha: 0.20)),
            ),
            child: Icon(Icons.auto_graph_rounded,
                size: 18, color: AppColors.primaryMain),
          ),
        ),
      );

  Widget _btnNovo(BuildContext context) => Tooltip(
        message: 'Novo pedido de compra',
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            pedidoCompraCtrl.iniciarPlanilha();
            push(context, const PedidoCompraPlanilhaPage());
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryMain.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.primaryMain.withValues(alpha: 0.20)),
            ),
            child: Icon(Icons.add, size: 18, color: AppColors.primaryMain),
          ),
        ),
      );


  // ── Card de grupo ativo (pendente ou confirmado) ──────────────────────────

  Widget _cardGrupoAtivo(
      BuildContext context, List<PedidoCompraModel> itens) {
    final status = itens.first.status;
    final isPendente = status == PedidoCompraStatus.pendente;
    final accentColor = isPendente ? Colors.orange[700]! : Colors.blue[700]!;
    final semFornecedor = itens.first.fabricanteId.isEmpty;
    final fabricante = semFornecedor
        ? 'Fornecedor a definir'
        : itens.first.fabricante.nome;
    final totalKg = itens.fold<double>(0, (s, i) => s + i.quantidade);
    final dataPrevista = itens.first.dataPrevista;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: accentColor.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            // ── Cabeçalho ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.06),
                border: Border(
                    bottom: BorderSide(
                        color: accentColor.withValues(alpha: 0.15))),
              ),
              child: Row(children: [
                Icon(Icons.factory_outlined,
                    size: 16, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          fabricante,
                          style: semFornecedor
                              ? AppCss.minimumRegular
                                  .setSize(13)
                                  .setColor(Colors.grey[400]!)
                                  .copyWith(fontStyle: FontStyle.italic)
                              : AppCss.minimumBold.setSize(14)),
                      if (!isPendente && dataPrevista != null)
                        Row(children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 11,
                              color: Colors.blue[400]),
                          const SizedBox(width: 4),
                          Text(
                            'Previsto: ${dataPrevista.day.toString().padLeft(2, '0')}/'
                            '${dataPrevista.month.toString().padLeft(2, '0')}/'
                            '${dataPrevista.year}',
                            style: AppCss.minimumRegular
                                .setColor(Colors.blue[400]!)
                                .setSize(11),
                          ),
                        ]),
                    ],
                  ),
                ),
                _badgeStatus(status),
                if (!isPendente && itens.first.numeroPedido != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      'N ${itens.first.numeroPedido!}',
                      style: AppCss.minimumBold.setSize(11).setColor(Colors.blue[700]!),
                    ),
                  ),
                ],
              ]),
            ),

            // ── Itens (ordenados pelo index do produto) ───────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Column(
                children: [
                  ...([...itens]..sort((a, b) =>
                          a.produto.sortIndex.compareTo(b.produto.sortIndex)))
                      .map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.50),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${item.produto.nome} · ${item.produto.descricao}',
                                  style: AppCss.minimumRegular.setSize(12),
                                ),
                              ),
                              Text(
                                item.quantidade.toKg(),
                                style: AppCss.minimumBold
                                    .setColor(AppColors.primaryMain)
                                    .setSize(12),
                              ),
                            ]),
                          )),
                  const Divider(height: 14),
                  Row(children: [
                    Icon(Icons.scale_outlined,
                        size: 13, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text('Total: ',
                        style: AppCss.minimumRegular
                            .setColor(Colors.grey[500]!)
                            .setSize(11)),
                    Text(totalKg.toKg(),
                        style: AppCss.minimumBold.setSize(12)),
                    const Spacer(),
                    Icon(Icons.calendar_today_outlined,
                        size: 11, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text(
                      itens.first.createdAt.ddMMyyyy(),
                      style: AppCss.minimumRegular
                          .setColor(Colors.grey[400]!)
                          .setSize(11),
                    ),
                  ]),
                ],
              ),
            ),

            // ── Ações por status ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isPendente) ...[
                    // Pendente: Cotação + Excluir + Editar + Confirmar
                    Tooltip(
                      message: 'Gerar Pedido de Cotação',
                      preferBelow: false,
                      waitDuration: const Duration(milliseconds: 300),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange[700],
                          side: BorderSide(
                              color: Colors.orange.withValues(alpha: 0.40)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () async {
                          // Dialog para escolher o fornecedor
                          final fabricantes =
                              [...BackendClient.fabricantes.data]
                                ..sort((a, b) => a.nome.compareTo(b.nome));
                          // Pré-seleciona o fornecedor já atribuído ao grupo (se existir)
                          final fabricanteAtualId = itens.first.fabricanteId;
                          FabricanteModel? escolhido = fabricantes.isEmpty
                              ? null
                              : fabricantes.firstWhere(
                                  (f) => f.id == fabricanteAtualId,
                                  orElse: () => fabricantes.first,
                                );
                          await showDialog<void>(
                            context: context,
                            builder: (_) => StatefulBuilder(
                              builder: (ctx, setS) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.request_quote_outlined,
                                        color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Pedido de Cotação'),
                                  ],
                                ),
                                content: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 360),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Selecione o fornecedor para quem deseja enviar esta cotação.',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 16),
                                      DropdownButtonFormField<FabricanteModel>(
                                        value: escolhido,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Selecione o fornecedor',
                                          prefixIcon: const Icon(
                                              Icons.factory_outlined,
                                              size: 18),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        items: fabricantes
                                            .map((f) => DropdownMenuItem(
                                                  value: f,
                                                  child: Text(f.nome),
                                                ))
                                            .toList(),
                                        onChanged: (v) =>
                                            setS(() => escolhido = v),
                                      ),
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: escolhido != null
                                        ? () {
                                            Navigator.pop(ctx);
                                            pedidoCompraCtrl.onEnviarCotacaoWhatsApp(
                                              context,
                                              itens,
                                              escolhido!,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(
                                        Icons.send_outlined,
                                        size: 15),
                                    label: const Text('WhatsApp'),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange[700],
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: escolhido != null
                                        ? () {
                                            Navigator.pop(ctx);
                                            pedidoCompraCtrl.onGerarCotacao(
                                              context,
                                              itens,
                                              escolhido!,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        size: 15),
                                    label: const Text('Gerar PDF'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: const Icon(Icons.request_quote_outlined, size: 16),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Excluir pedido',
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red[400],
                          side: BorderSide(
                              color: Colors.red.withValues(alpha: 0.40)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () =>
                            pedidoCompraCtrl.onExcluirGrupo(context, itens),
                        child: const Icon(Icons.delete_outline, size: 16),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.40)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: () =>
                          pedidoCompraCtrl.onIniciarEdicao(context, itens),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Editar',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => pedidoCompraCtrl
                          .onConfirmarGrupo(context, itens),
                      icon: const Icon(Icons.thumb_up_outlined, size: 15),
                      label: const Text('Confirmar',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ] else ...[
                    // Confirmado: Pedido de Compra + Voltar para Pendente + Efetivar
                    Tooltip(
                      message: 'Gerar Pedido de Compra',
                      preferBelow: false,
                      waitDuration: const Duration(milliseconds: 300),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                          side: BorderSide(
                              color: Colors.blue.withValues(alpha: 0.40)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        onPressed: () => pedidoCompraCtrl
                            .onGerarPedidoCompra(context, itens),
                        child:
                            const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[700],
                        side: BorderSide(
                            color: Colors.orange.withValues(alpha: 0.40)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => pedidoCompraCtrl
                          .onVoltarParaPendente(context, itens),
                      icon: const Icon(Icons.undo, size: 15),
                      label: const Text('Voltar para Pendente',
                          style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: () =>
                          pedidoCompraCtrl.onEfetivarGrupo(context, itens),
                      icon: const Icon(Icons.check, size: 15),
                      label: const Text('Efetivar',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card de grupo efetivado ───────────────────────────────────────────────

  Widget _cardGrupoEfetivado(List<PedidoCompraModel> itens) {
    final fabricante = itens.first.fabricante.nome;
    final totalPedido =
        itens.fold<double>(0, (s, i) => s + i.quantidade);
    final totalRecebido =
        itens.fold<double>(0, (s, i) => s + (i.quantidadeRecebida ?? 0));

    return Opacity(
      opacity: 0.65,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.06),
                  border: Border(
                      bottom: BorderSide(
                          color: Colors.green.withValues(alpha: 0.15))),
                ),
                child: Row(children: [
                  Icon(Icons.factory_outlined,
                      size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(fabricante,
                          style: AppCss.minimumBold.setSize(13))),
                  _badgeStatus(PedidoCompraStatus.convertido),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    ...([...itens]..sort((a, b) =>
                            a.produto.sortIndex
                                .compareTo(b.produto.sortIndex)))
                        .map((item) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                    '${item.produto.nome} · ${item.produto.descricao}',
                                    style: AppCss.minimumRegular
                                        .setColor(Colors.grey[600]!)
                                        .setSize(11),
                                  ),
                                ),
                                Text(item.quantidade.toKg(),
                                    style: AppCss.minimumRegular
                                        .setColor(Colors.grey[500]!)
                                        .setSize(11)),
                                if (item.quantidadeRecebida != null)
                                  Text(
                                    ' → ${item.quantidadeRecebida!.toKg()}',
                                    style: AppCss.minimumBold
                                        .setColor(Colors.green[700]!)
                                        .setSize(11),
                                  ),
                              ]),
                            )),
                    const Divider(height: 12),
                    Row(children: [
                      Text('Total pedido: ${totalPedido.toKg()}',
                          style: AppCss.minimumRegular
                              .setColor(Colors.grey[500]!)
                              .setSize(11)),
                      const SizedBox(width: 8),
                      Text('→ Recebido: ${totalRecebido.toKg()}',
                          style: AppCss.minimumBold
                              .setColor(Colors.green[700]!)
                              .setSize(11)),
                      const Spacer(),
                      Text(itens.first.updatedAt.ddMMyyyy(),
                          style: AppCss.minimumRegular
                              .setColor(Colors.grey[400]!)
                              .setSize(10)),
                    ]),
                    const SizedBox(height: 8),
                    // Botão estornar
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange[700],
                          side: BorderSide(
                              color: Colors.orange.withValues(alpha: 0.40)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                        ),
                        onPressed: () =>
                            pedidoCompraCtrl.onEstornarGrupo(context, itens),
                        icon: const Icon(Icons.undo, size: 14),
                        label: const Text('Estornar Compra',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _badgeStatus(PedidoCompraStatus status) {
    final color = switch (status) {
      PedidoCompraStatus.pendente => Colors.orange[700]!,
      PedidoCompraStatus.confirmado => Colors.blue[700]!,
      PedidoCompraStatus.convertido => Colors.green[700]!,
      PedidoCompraStatus.descartado => Colors.grey[500]!,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: AppCss.minimumBold.setColor(color).setSize(10),
      ),
    );
  }
}
