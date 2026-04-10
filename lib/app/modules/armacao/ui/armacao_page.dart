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
                      crossAxisCount: 3,
                      mainAxisExtent: 300, // Reduzido em 15% para caber melhor na tela
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

    return InkWell(
      onTap: () => push(context, ArmacaoElementosPage(pedido: pedido)),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Spacer(),
            _buildSection(
              'PRODUÇÃO (Peças)',
              totalQtd.toInt().toString(),
              resumo['aguardando']?['qtd'] ?? 0,
              resumo['armando']?['qtd'] ?? 0,
              resumo['pronto']?['qtd'] ?? 0,
              totalQtd,
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const SizedBox(height: 16),
            _buildSection(
              'CARGA (KG)',
              totalPeso.toStringAsFixed(1),
              resumo['aguardando']?['peso'] ?? 0,
              resumo['armando']?['peso'] ?? 0,
              resumo['pronto']?['peso'] ?? 0,
              totalPeso,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              pedido.localizador,
              style: AppCss.largeBold.setSize(22).setColor(AppColors.primaryDark),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[300]),
          ],
        ),
        Text(
          pedido.cliente.nome.toUpperCase(),
          style: AppCss.minimumBold.setSize(10).setColor(Colors.grey[400]!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSection(String title, String total, dynamic agu, dynamic prod,
      dynamic ok, double totalVal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppCss.minimumBold.setSize(9).setColor(Colors.grey[500]!)),
            Text(total, style: AppCss.mediumBold.setSize(16).setColor(AppColors.secondary)),
          ],
        ),
        const SizedBox(height: 8),
        _SegmentedBar(
          agu: (agu is num ? agu.toDouble() : 0.0),
          prod: (prod is num ? prod.toDouble() : 0.0),
          ok: (ok is num ? ok.toDouble() : 0.0),
          total: totalVal,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _statusInfo(agu.toString(), 'AGU', Colors.blue),
            _statusInfo(prod.toString(), 'PROD', Colors.orange),
            _statusInfo(ok.toString(), 'PRONTAS', Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _statusInfo(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppCss.mediumBold.setSize(13).setColor(color),
        ),
        Text(
          label,
          style: AppCss.minimumBold.setSize(8).setColor(color.withOpacity(0.7)),
        ),
      ],
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  final double agu;
  final double prod;
  final double ok;
  final double total;

  const _SegmentedBar({
    required this.agu,
    required this.prod,
    required this.ok,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 12,
        width: double.infinity,
        child: total == 0
            ? Container(color: Colors.grey[100])
            : Row(
                children: [
                  if (agu > 0)
                    Expanded(
                      flex: (agu * 1000).toInt(),
                      child: Container(color: Colors.blue),
                    ),
                  if (prod > 0)
                    Expanded(
                      flex: (prod * 1000).toInt(),
                      child: Container(color: Colors.orange),
                    ),
                  if (ok > 0)
                    Expanded(
                      flex: (ok * 1000).toInt(),
                      child: Container(color: Colors.green),
                    ),
                ],
              ),
      ),
    );
  }
}
