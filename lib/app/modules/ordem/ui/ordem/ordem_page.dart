import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/app_text_button.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/item_label.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materia_prima_bottom.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materias_primas_create_page.dart';
import 'package:aco_plus/app/modules/ordem/ordem_controller.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/ordem_status_widget.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/bitola/ordem_pedido_bitola_widget.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem_create_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem_exportar_pdf_tipo_bottom.dart';
import 'package:aco_plus/app/modules/ordem/view_models/ordem_view_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

class OrdemPage extends StatefulWidget {
  final String ordemId;
  final OrdemModel? ordem;
  const OrdemPage(this.ordemId, {this.ordem, super.key});

  @override
  State<OrdemPage> createState() => _OrdemPageState();
}

class _OrdemPageState extends State<OrdemPage> {
  // Prontos ocultos por padrão no modo operador por pedido
  bool _mostrarProntos = false;
  // Gráfico de produção oculto por padrão
  bool _mostrarGraficoStatus = false;

  @override
  void initState() {
    setWebTitle('Ordem');
    ordemCtrl.onInitPage(widget.ordemId, ordem: widget.ordem);
    super.initState();
  }

  @override
  void dispose() {
    ordemCtrl.onDisposePage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<MateriaPrimaModel>>(
      stream: FirestoreClient.materiaPrimas.dataStream.listen,
      builder: (_, materiasPrimas) => StreamOut<List<PedidoModel>>(
        stream: FirestoreClient.pedidos.dataStream.listen,
        builder: (_, pedidos) => StreamOut<OrdemModel>(
          stream: ordemCtrl.ordemStream.listen,
          builder: (_, ordem) => AppScaffold(
            resizeAvoid: true,
            appBar: AppBar(
              iconTheme: const IconThemeData(color: Colors.white, size: 20),
              actions: usuario.isOperador
                  ? () {
                      final isModoPorPedido =
                          PreferencesService.apontamentoProducaoCD.value !=
                              'por_os';
                      final qtdeProntos = isModoPorPedido
                          ? ordem.produtos
                              .where((p) =>
                                  p.statusView.status ==
                                  PedidoBitolaStatus.pronto)
                              .length
                          : 0;
                      return qtdeProntos == 0
                          ? <Widget>[]
                          : [
                              GestureDetector(
                                onTap: () => setState(
                                    () => _mostrarProntos = !_mostrarProntos),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _mostrarProntos
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.25),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$qtdeProntos pronto${qtdeProntos > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ];
                    }()
                  : [
                      if (!ordem.isArchived)
                        IconButton(
                          onPressed: () async =>
                              ordemCtrl.onArchive(context, ordem),
                          icon: Icon(Icons.archive, color: AppColors.white),
                        ),
                      if (ordem.isArchived)
                        IconButton(
                          onPressed: () async =>
                              ordemCtrl.onUnarchive(context, ordem, 2),
                          icon: Icon(Icons.unarchive, color: AppColors.white),
                        ),
                      const W(8),
                      IconButton(
                        onPressed: () async {
                          final tipo = await showOrdemExportarPdfTipoBottom();
                          if (tipo != null) {
                            if (tipo == OrdemExportarPdfTipo.relatorio) {
                              await ordemCtrl.onGenerateRelatorioPDF(ordem);
                            } else {
                              await ordemCtrl.onGenerateEtiquetasPDF(ordem);
                            }
                          }
                        },
                        icon: Icon(
                          Icons.picture_as_pdf,
                          color: AppColors.white,
                        ),
                      ),
                      const W(8),
                      IconButton(
                        onPressed: () async =>
                            push(context, OrdemCreatePage(ordem: ordem)),
                        icon: Icon(Icons.edit, color: AppColors.white),
                      ),
                      const W(8),
                      IconButton(
                        onPressed: () async =>
                            ordemCtrl.onDelete(context, ordem),
                        icon: Icon(Icons.delete, color: AppColors.white),
                      ),
                      const W(8),
                    ],
              title: Text(
                'Ordem ${ordem.localizator}',
                style: AppCss.largeBold.setColor(AppColors.white),
              ),
              backgroundColor: AppColors.primaryMain,
            ),
            body: StreamOut<OrdemModel>(
              stream: ordemCtrl.ordemStream.listen,
              builder: (_, form) => body(pedidos, form),
            ),
          ),
        ),
      ),
    );
  }

  Widget body(List<PedidoModel> pedidos, OrdemModel ordem) {
    // Modo operador + apontamento por pedido: ocultar prontos
    final isModoPorPedido = usuario.isOperador &&
        PreferencesService.apontamentoProducaoCD.value != 'por_os';

    final produtos = isModoPorPedido && !_mostrarProntos
        ? ordem.produtos
            .where((p) => p.statusView.status != PedidoBitolaStatus.pronto)
            .toList()
        : ordem.produtos;



    return RefreshIndicator(
      onRefresh: () async {
        await FirestoreClient.ordens.fetch();
        ordemCtrl.getOrdemById(widget.ordemId);
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (ordem.freezed.isFreezed) unfreezedWidget(ordem),
          Container(
            color: ordem.freezed.isFreezed
                ? Colors.grey.withValues(alpha: 0.1)
                : null,
            child: Column(
              children: [
                _descriptionWidget(ordem),
                const Divisor(),
                if (_mostrarGraficoStatus) OrdemStatusWidget(ordem: ordem),
                for (final produto in produtos)
                  OrdemPedidoProdutoWidget(
                    produto: produto,
                    ordem: ordem,
                    materiaPrima: ordemCtrl.getMateriaPrimaByPedidoProduto(
                      pedidos,
                      produto,
                    ),
                  ),
                if (usuario.isNotOperador)
                  if (!ordem.freezed.isFreezed &&
                      ordem.status != PedidoBitolaStatus.pronto)
                    _freezedWidget(ordem),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _descriptionWidget(OrdemModel ordem) {
    final materiaPrimaLabel = ordem.materiaPrima?.label;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Linha única: bitola + hora + matéria prima ───────────
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _pill(
                icon: Icons.straighten_outlined,
                label: ordem.produto.nome,
                color: AppColors.primaryMain,
              ),
              _pill(
                icon: Icons.schedule_rounded,
                label: ordem.createdAt.textHour(),
                color: Colors.blueGrey,
              ),
              if (materiaPrimaLabel != null)
                GestureDetector(
                  onTap: () async {
                    final result =
                        await showMateriaPrimaBottom(ordem.materiaPrima!);
                    if (result != null && context.mounted) {
                      push(context,
                          MateriaPrimaCreatePage(materiaPrima: result));
                    }
                  },
                  child: _pill(
                    icon: Icons.inventory_2_outlined,
                    label: materiaPrimaLabel,
                    color: Colors.orange,
                    trailing: const Icon(Icons.chevron_right,
                        size: 12, color: Colors.orange),
                  ),
                ),
              if (ordem.endAt != null)
                _pill(
                  icon: Icons.check_circle_outline,
                  label: 'Finalizada ${ordem.endAt.text()}',
                  color: Colors.green,
                ),
            ],
          ),

          // ─── Toggle do gráfico de produção ────────────────────────
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () =>
                setState(() => _mostrarGraficoStatus = !_mostrarGraficoStatus),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 15, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    'Gráfico de produção',
                    style: AppCss.minimumRegular
                        .setSize(12)
                        .setColor(Colors.grey[600]!),
                  ),
                  const Spacer(),
                  Icon(
                    _mostrarGraficoStatus
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.85),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 3), trailing],
        ],
      ),
    );
  }

  Widget _freezedWidget(OrdemModel ordem) {
    return Column(
      children: [
        const Divisor(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.stop_circle_outlined),
                  const W(8),
                  Expanded(
                    child: Text('Congelar Ordem', style: AppCss.largeBold),
                  ),
                ],
              ),
              const H(8),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: AppField(
                      label: 'Motivo do Congelamento',
                      required: false,
                      controller: ordem.freezed.reason,
                      onChanged: (e) => ordemCtrl.ordemStream.update(),
                    ),
                  ),
                  const W(8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(top: 26),
                      child: AppTextButton(
                        label: 'Confirmar',
                        onPressed: () async =>
                            await ordemCtrl.onFreezed(context, ordem),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget unfreezedWidget(OrdemModel ordem) {
    return Column(
      children: [
        const Divisor(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.stop_circle_outlined),
                  const W(12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ordem Congelada', style: AppCss.largeBold),
                        Text(
                          'Congelada ás ${ordem.freezed.updatedAt.textHour()}',
                          style: AppCss.minimumRegular.copyWith(
                            color: AppColors.black.withValues(alpha: 0.6),
                            fontSize: 12,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AppTextButton(
                      label: 'Descongelar Ordem',
                      onPressed: () async =>
                          await ordemCtrl.onFreezed(context, ordem),
                    ),
                  ),
                ],
              ),
              const H(16),
              ItemLabel('Motivo', ordem.freezed.reason.text),
            ],
          ),
        ),
      ],
    );
  }
}
