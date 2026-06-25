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
    armacaoCtrl.onInit();
    await AppSupabaseClient.pedidos.fetch();
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
                  Text('Aguarde, carregando pedidos...',
                      style: AppCss.mediumRegular),
                ],
              ),
            );
          }
          return StreamOut<List<PedidoModel>>(
            stream: armacaoCtrl.pedidosStream.listen,
            builder: (_, pedidos) => pedidos.isEmpty
                ? const EmptyData(
                    message: 'Nenhum lote para armação encontrado!')
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final largura = constraints.maxWidth;
                      final isRetrato = MediaQuery.of(context).orientation ==
                          Orientation.portrait;

                      // Retrato: 2 colunas, cards menores
                      // Paisagem: 3 colunas, cards maiores
                      final colunas = isRetrato
                          ? (largura < 500 ? 1 : 2)
                          : (largura < 600 ? 2 : 3);
                      final alturaCard = isRetrato ? 240.0 : 290.0;
                      final spacing = isRetrato ? 16.0 : 24.0;

                      return GridView.builder(
                        padding: EdgeInsets.all(spacing),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: colunas,
                          mainAxisExtent: alturaCard,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                        ),
                        itemCount: pedidos.length,
                        itemBuilder: (context, index) {
                          final pedido = pedidos[index];
                          return _PedidoArmacaoCard(
                            pedido: pedido,
                            compacto: isRetrato,
                          );
                        },
                      );
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
  final bool compacto;

  const _PedidoArmacaoCard({
    required this.pedido,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final resumo = pedido.armacaoResumo['details'] ?? {};

    return InkWell(
      onTap: () => push(context, ArmacaoElementosPage(pedido: pedido)),
      borderRadius: BorderRadius.circular(compacto ? 16 : 25),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(compacto ? 16 : 25),
          border: Border.all(color: Colors.black, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
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
                padding: EdgeInsets.fromLTRB(
                  compacto ? 10 : 16,
                  compacto ? 8 : 12,
                  compacto ? 10 : 16,
                  compacto ? 12 : 20,
                ),
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
      height: compacto ? 45 : 60,
      color: Colors.black.withValues(alpha: 0.08),
    );
  }

  Widget _buildHeader() {
    final paddingV = compacto ? 12.0 : 20.0;
    final paddingH = compacto ? 12.0 : 16.0;
    final localizadorSize = compacto ? 18.0 : 25.0;
    final clienteSize = compacto ? 12.0 : 15.0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(compacto ? 8 : 12),
      padding: EdgeInsets.symmetric(vertical: paddingV, horizontal: paddingH),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(compacto ? 10 : 15),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              pedido.localizador,
              style: AppCss.largeBold
                  .setSize(localizadorSize)
                  .setColor(Colors.white)
                  .copyWith(letterSpacing: 2),
              maxLines: 1,
            ),
          ),
          SizedBox(height: compacto ? 4 : 6),
          Text(
            pedido.cliente.nome.toUpperCase(),
            style: AppCss.largeBold
                .setSize(clienteSize)
                .setColor(Colors.white.withValues(alpha: 0.6)),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (pedido.descricao.isNotEmpty && !compacto) ...[
            const SizedBox(height: 4),
            Text(
              pedido.descricao,
              style: AppCss.minimumRegular
                  .setSize(12)
                  .setColor(Colors.white.withValues(alpha: 0.45)),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColumn(String title, String pc, String kg, Color color) {
    final titleSize = compacto ? 10.0 : 12.0;
    final pcSize = compacto ? 18.0 : 24.0;
    final kgSize = compacto ? 13.0 : 16.0;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: AppCss.largeBold.setSize(titleSize).setColor(color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: compacto ? 8 : 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              pc,
              style: AppCss.largeBold
                  .setSize(pcSize)
                  .setColor(Colors.black)
                  .copyWith(letterSpacing: -0.5),
            ),
          ),
          SizedBox(height: compacto ? 4 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              kg,
              style: AppCss.largeBold
                  .setSize(kgSize)
                  .setColor(Colors.black)
                  .copyWith(letterSpacing: -0.3),
            ),
          ),
        ],
      ),
    );
  }
}
