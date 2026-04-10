import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
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
  @override
  void initState() {
    setWebTitle('Armação');
    armacaoCtrl.onInit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'MÓDULO DE ARMAÇÃO',
          style: AppCss.largeBold.setColor(AppColors.white).setSize(18),
        ),
        backgroundColor: AppColors.primaryMain,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.primaryMain,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: AppField(
              hint: 'Pesquisar Localizador / Cliente',
              controller: armacaoCtrl.search,
              suffixIcon: Icons.search,
              onChanged: armacaoCtrl.onSearch,
              color: AppColors.white,
            ),
          ),
          Expanded(
            child: StreamOut<List<PedidoModel>>(
              stream: armacaoCtrl.pedidosStream.listen,
              builder: (_, pedidos) => pedidos.isEmpty
                  ? const EmptyData()
                  : GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        mainAxisExtent: 220,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                      ),
                      itemCount: pedidos.length,
                      itemBuilder: (context, index) {
                        final pedido = pedidos[index];
                        final summary = armacaoCtrl.getSummary(pedido.id);
                        return _PedidoArmacaoCard(pedido: pedido, summary: summary);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PedidoArmacaoCard extends StatelessWidget {
  final PedidoModel pedido;
  final ArmacaoSummary summary;

  const _PedidoArmacaoCard({required this.pedido, required this.summary});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => push(context, ArmacaoElementosPage(pedido: pedido)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header: Localizador
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryMain.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pedido.localizador,
                      style: AppCss.largeBold.setSize(20).setColor(AppColors.primaryMain),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${summary.totalElementos} elem.',
                      style: AppCss.mediumBold.setColor(AppColors.secondary).setSize(14),
                    ),
                  ),
                ],
              ),
            ),
            // Body: Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pedido.cliente.nome,
                      style: AppCss.mediumBold.setSize(14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Tabela de Bitolas
                    if (summary.pesoPorBitola.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: summary.pesoPorBitola.entries.map((e) {
                          final produto = AppSupabaseClient.produtos.getById(e.key);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${produto.labelMinified}: ${e.value.toStringAsFixed(1)}kg',
                              style: AppCss.mediumBold.setSize(12).setColor(Colors.grey[800]),
                            ),
                          );
                        }).toList(),
                      ),
                    const Spacer(),
                    // Peso Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'TOTAL:',
                          style: AppCss.minimumBold.setColor(Colors.grey[500]),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${summary.pesoTotal.toStringAsFixed(2)} kg',
                          style: AppCss.largeBold.setSize(18),
                        ),
                      ],
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
}
