import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/fullscreen_button.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/armacao/armacao_controller.dart';
import 'package:aco_plus/app/modules/armacao/ui/armacao_elementos_page.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add([FullscreenButton()]);
    });
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
                      mainAxisExtent: 290, // Reduzido para caber sem rolar
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
      borderRadius: BorderRadius.circular(25),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(
                  children: [
                    _buildColumn(
                      'AGUARDANDO',
                      '${resumo['aguardando']?['qtd'] ?? 0} pc',
                      '${(resumo['aguardando']?['peso'] ?? 0).toStringAsFixed(1)} kg',
                      Colors.blue.shade700,
                    ),
                    _vDivider(),
                    _buildColumn(
                      'ARMANDO',
                      '${resumo['armando']?['qtd'] ?? 0} pc',
                      '${(resumo['armando']?['peso'] ?? 0).toStringAsFixed(1)} kg',
                      Colors.orange.shade800,
                    ),
                    _vDivider(),
                    _buildColumn(
                      'PRONTO',
                      '${resumo['pronto']?['qtd'] ?? 0} pc',
                      '${(resumo['pronto']?['peso'] ?? 0).toStringAsFixed(1)} kg',
                      Colors.green.shade700,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1.5,
      height: 60,
      color: Colors.black.withOpacity(0.08),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            pedido.localizador,
            style: AppCss.largeBold.setSize(25).setColor(Colors.white).copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Text(
            pedido.cliente.nome.toUpperCase(),
            style: AppCss.largeBold.setSize(15).setColor(Colors.white.withOpacity(0.6)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(String title, String pc, String kg, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: AppCss.largeBold.setSize(12).setColor(color),
          ),
          const SizedBox(height: 16),
          Text(
            pc,
            style: AppCss.largeBold.setSize(24).setColor(Colors.black),
          ),
          const SizedBox(height: 8),
          Text(
            kg,
            style: AppCss.largeBold.setSize(18).setColor(Colors.black),
          ),
        ],
      ),
    );
  }
}
