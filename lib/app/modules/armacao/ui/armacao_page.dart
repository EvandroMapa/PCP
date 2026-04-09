import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/armacao/armacao_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_page.dart';
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
      appBar: AppBar(
        title: Text(
          'Pedidos para Armação',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        backgroundColor: AppColors.primaryMain,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppField(
              hint: 'Pesquisar Localizador / Cliente',
              controller: armacaoCtrl.search,
              suffixIcon: Icons.search,
              onChanged: armacaoCtrl.onSearch,
            ),
          ),
          Expanded(
            child: StreamOut<List<PedidoModel>>(
              stream: armacaoCtrl.pedidosStream.listen,
              builder: (_, pedidos) => pedidos.isEmpty
                  ? const EmptyData()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: pedidos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final pedido = pedidos[index];
                        return ListTile(
                          onTap: () => push(
                            context,
                            PedidoPage(
                              pedido: pedido,
                              reason: PedidoInitReason.page,
                            ),
                          ),
                          title: Text(
                            pedido.localizador,
                            style: AppCss.mediumBold,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pedido.cliente.nome),
                              Text(
                                'Etapa: ${pedido.step.name}',
                                style: AppCss.minimumRegular.setColor(pedido.step.color),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
