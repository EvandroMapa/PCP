import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/armacao/armacao_controller.dart';
import 'package:aco_plus/app/modules/armacao/ui/armacao_elementos_page.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ArmacaoPage extends StatefulWidget {
  const ArmacaoPage({super.key});

  @override
  State<ArmacaoPage> createState() => _ArmacaoPageState();
}

class _ArmacaoPageState extends State<ArmacaoPage> {
  bool _isLoading = false;

  @override
  void initState() {
    setWebTitle('Armação');
    _init();
    super.initState();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    armacaoCtrl.onInit();
    await AppSupabaseClient.pedidos.fetch();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        elevation: 0,
        title: const SizedBox.shrink(), // Remove o título redundante conforme solicitado
      ),
      body: StreamOut<bool>(
        stream: armacaoCtrl.loadingStream.listen,
        builder: (_, isLoading) {
          if (isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Aguarde, carregando pedidos...', style: AppCss.mediumRegular),
                ],
              ),
            );
          }
          return StreamOut<List<PedidoModel>>(
            stream: armacaoCtrl.pedidosStream.listen,
            builder: (_, pedidos) => pedidos.isEmpty
                ? const EmptyData(message: 'Nenhum lote para armação encontrado!')
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, // Força layout 3x2 conforme solicitado
                      mainAxisExtent: 380, // Aumentado para cartões maiores
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                    ),
                    itemCount: pedidos.length,
                    itemBuilder: (context, index) {
                      final pedido = pedidos[index];
                      return _PedidoArmacaoCard(pedido: pedido);
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _PedidoArmacaoCard extends StatelessWidget {
  final PedidoModel pedido;

  const _PedidoArmacaoCard({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final resumo = pedido.armacaoResumo['details'] ?? {};
    final double totalQtd = (pedido.armacaoResumo['total_qtd'] ?? 0).toDouble();
    final double totalPeso = (pedido.armacaoResumo['total_peso'] ?? 0).toDouble();

    final List<_ChartData> qtdData = [
      _ChartData('Aguardando', (resumo['aguardando']?['qtd'] ?? 0).toDouble(), Colors.blue),
      _ChartData('Armando', (resumo['armando']?['qtd'] ?? 0).toDouble(), Colors.orange),
      _ChartData('Pronto', (resumo['pronto']?['qtd'] ?? 0).toDouble(), Colors.green),
    ];

    if (totalQtd == 0) qtdData.add(_ChartData('Vazio', 1, Colors.grey[200]!));

    final List<_ChartData> pesoData = [
      _ChartData('Aguardando', (resumo['aguardando']?['peso'] ?? 0).toDouble(), Colors.blue),
      _ChartData('Armando', (resumo['armando']?['peso'] ?? 0).toDouble(), Colors.orange),
      _ChartData('Pronto', (resumo['pronto']?['peso'] ?? 0).toDouble(), Colors.green),
    ];

    if (totalPeso == 0) pesoData.add(_ChartData('Vazio', 1, Colors.grey[200]!));

    return InkWell(
      onTap: () => push(context, ArmacaoElementosPage(pedido: pedido)),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryMain.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                pedido.localizador,
                style: AppCss.largeBold.setSize(28).setColor(AppColors.primaryDark),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pedido.cliente.nome.toUpperCase(),
              style: AppCss.minimumBold.setSize(12).setColor(Colors.grey[400]!),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(child: _buildChart('PEÇAS', qtdData, totalQtd.toInt().toString())),
                const SizedBox(width: 16),
                Expanded(child: _buildChart('PESO (KG)', pesoData, totalPeso.toStringAsFixed(0))),
              ],
            ),
            const SizedBox(height: 16),
            _buildLegend(),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(String title, List<_ChartData> data, String total) {
    return Column(
      children: [
        SizedBox(
          height: 140, // Aumentado para melhor visibilidade
          child: SfCircularChart(
            margin: EdgeInsets.zero,
            series: <CircularSeries>[
              DoughnutSeries<_ChartData, String>(
                dataSource: data,
                xValueMapper: (_ChartData data, _) => data.x,
                yValueMapper: (_ChartData data, _) => data.y,
                pointColorMapper: (_ChartData data, _) => data.color,
                innerRadius: '70%',
                animationDuration: 1000,
              ),
            ],
            annotations: <CircularChartAnnotation>[
              CircularChartAnnotation(
                widget: Text(
                  total,
                  style: AppCss.largeBold.setSize(24).setColor(AppColors.secondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: AppCss.mediumBold.setSize(10).setColor(Colors.grey[600]!)),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('AGUARD.', Colors.blue),
        const SizedBox(width: 16),
        _legendItem('ARMANDO', Colors.orange),
        const SizedBox(width: 16),
        _legendItem('PRONTO', Colors.green),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppCss.minimumBold.setSize(10).setColor(Colors.grey[700]!),
        ),
      ],
    );
  }
}

class _ChartData {
  _ChartData(this.x, this.y, this.color);
  final String x;
  final double y;
  final Color color;
}
