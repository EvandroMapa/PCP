import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/models/tag_model.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/posicao_progresso_helper.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materia_prima_bottom.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materias_primas_create_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/produto/ordem_pedido_elementos_dialog.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/produto/ordem_pedido_produto_pause_widget.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/produto/status/ordem_pedido_status_normal_widget.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/components/produto/status/ordem_pedido_status_operator_widget.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

class OrdemPedidoProdutoWidget extends StatelessWidget {
  final PedidoProdutoModel produto;
  final OrdemModel ordem;
  final MateriaPrimaModel? materiaPrima;

  const OrdemPedidoProdutoWidget({
    super.key,
    required this.produto,
    required this.ordem,
    required this.materiaPrima,
  });

  @override
  Widget build(BuildContext context) {
    final status = produto.statusView.status;
    final statusColor = produto.isPaused ? Colors.orange : status.color;

    // Verifica se deve usar modo "por OS"
    final isModoPorOS = usuario.isOperador &&
        PreferencesService.apontamentoProducaoCD.value == 'por_os' &&
        _pedidoTemElementos();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: isModoPorOS ? () => _openElementosDialog(context) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: produto.isPaused
                ? Colors.orange.withValues(alpha: 0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Borda lateral colorida pelo status
                Container(width: 4, color: statusColor),
                // Conteúdo
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: localizador + tags
                        Row(
                          children: [
                            if (produto.isPaused) _pauseTagWidget(),
                            if (produto.pedido.tags.isNotEmpty)
                              _tagWidget(produto.pedido.tags.first),
                            Text(
                              produto.pedido.localizador,
                              style: AppCss.mediumBold.setSize(15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Peso + cliente/obra
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryMain
                                    .withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                produto.qtde.toKg(),
                                style: AppCss.minimumBold
                                    .setSize(12)
                                    .setColor(AppColors.primaryMain),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${produto.cliente.nome} · ${produto.obra.descricao}',
                                style: AppCss.minimumRegular
                                    .setSize(12)
                                    .setColor(Colors.grey[600]!),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (produto.pedido.deliveryAt != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.event_outlined,
                                  size: 12, color: Colors.grey[400]),
                              const SizedBox(width: 4),
                              Text(
                                'Entrega: ${produto.pedido.deliveryAt?.text()}',
                                style: AppCss.minimumRegular
                                    .setSize(11)
                                    .setColor(Colors.grey[500]!),
                              ),
                            ],
                          ),
                        ],
                        if (materiaPrima != null) ...[
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () async {
                              final result =
                                  await showMateriaPrimaBottom(materiaPrima!);
                              if (result != null) {
                                push(
                                    context,
                                    MateriaPrimaCreatePage(
                                        materiaPrima: materiaPrima));
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory_2_outlined,
                                    size: 12, color: Colors.orange[400]),
                                const SizedBox(width: 4),
                                Text(
                                  materiaPrima!.label,
                                  style: AppCss.minimumRegular
                                      .setSize(11)
                                      .setColor(Colors.orange[700]!)
                                      .copyWith(
                                          decoration: TextDecoration.underline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Botões de status + pause
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statusWidget(readOnly: isModoPorOS),
                      if (!isModoPorOS &&
                          produto.statusView.status ==
                              PedidoProdutoStatus.produzindo)
                        OrdemPedidoProdutoPauseWidget(
                            ordem: ordem, produto: produto),
                      if (isModoPorOS) _buildMiniProgressOS(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Verifica se o pedido associado a este produto tem elementos/OS cadastrados
  bool _pedidoTemElementos() {
    return AppSupabaseClient.elementos.data
        .any((e) => e.pedidoId == produto.pedidoId);
  }

  /// Abre a página fullscreen de controle por OS/Elemento
  void _openElementosDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrdemPedidoElementosPage(
          produto: produto,
          ordem: ordem,
        ),
      ),
    );
  }

  Widget _buildMiniProgressOS() {
    final result =
        calcularProgressoPosicoes(produto.pedidoId, ordem.produto.id);
    if (!result.hasData) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 12, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text('Clique para abrir OS',
                style: TextStyle(fontSize: 10, color: Colors.grey[400])),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _miniCircle('Ag.', result.prcntAguardando,
                  PosicaoStatus.aguardando.color),
              const SizedBox(width: 8),
              _miniCircle('Prod.', result.prcntProduzindo,
                  PosicaoStatus.produzindo.color),
              const SizedBox(width: 8),
              _miniCircle(
                  'Pronto', result.prcntPronto, PosicaoStatus.pronto.color),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 10, color: Colors.grey[400]),
              const SizedBox(width: 3),
              Text('Abrir OS',
                  style: TextStyle(fontSize: 9, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniCircle(String label, double prcnt, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: prcnt,
                backgroundColor: color.withValues(alpha: 0.15),
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                '${(prcnt * 100).toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 8, color: Colors.grey[500])),
      ],
    );
  }

  Widget _statusWidget({bool readOnly = false}) {
    return usuario.isOperador
        ? OrdemPedidoStatusOperatorWidget(
            produto: produto, ordem: ordem, readOnly: readOnly)
        : OrdemPedidoStatusNormalWidget(produto: produto, ordem: ordem);
  }

  Widget _tagWidget(TagModel tag) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tag.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag.nome,
        style: TextStyle(
          color:
              tag.color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _pauseTagWidget() {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PAUSADO',
        style: TextStyle(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}
