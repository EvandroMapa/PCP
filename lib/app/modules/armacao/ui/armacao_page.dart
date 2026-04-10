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
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            const Spacer(),
            Row(
              children: [
                _buildColumn(
                  'AGUARDANDO',
                  '${resumo['aguardando']?['qtd'] ?? 0} pc',
                  '${(resumo['aguardando']?['peso'] ?? 0).toStringAsFixed(1)} kg',
                  Colors.blue,
                ),
                _vDivider(),
                _buildColumn(
                  'ARMANDO',
                  '${resumo['armando']?['qtd'] ?? 0} pc',
                  '${(resumo['armando']?['peso'] ?? 0).toStringAsFixed(1)} kg',
                  Colors.orange,
                ),
                _vDivider(),
                _buildColumn(
                  'PRONTO',
                  '${resumo['pronto']?['qtd'] ?? 0} pc',
                  '${(resumo['pronto']?['peso'] ?? 0).toStringAsFixed(1)} kg',
                  Colors.green,
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.grey.withOpacity(0.1),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          pedido.localizador,
          style: AppCss.largeBold.setSize(24).setColor(AppColors.primaryDark),
        ),
        const SizedBox(height: 4),
        Text(
          pedido.cliente.nome.toUpperCase(),
          style: AppCss.minimumBold.setSize(10).setColor(Colors.grey[400]!),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildColumn(String title, String pc, String kg, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: AppCss.minimumBold.setSize(9).setColor(color.withOpacity(0.8)),
          ),
          const SizedBox(height: 8),
          Text(
            pc,
            style: AppCss.mediumBold.setSize(16).setColor(color),
          ),
          const SizedBox(height: 4),
          Text(
            kg,
            style: AppCss.mediumBold.setSize(13).setColor(color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}
