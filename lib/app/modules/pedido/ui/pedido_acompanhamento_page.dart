import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/logo_helper.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/pedido/ui/components/pedido_tracker_timeline_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

// '/acompanhamento/pedido/0VO0BCbtfKlAkAVzqtpZd0V8m'
class PedidoAcompanhamentoPage extends StatefulWidget {
  final String id;

  const PedidoAcompanhamentoPage({required this.id, super.key});

  @override
  State<PedidoAcompanhamentoPage> createState() =>
      _PedidoAcompanhamentoPageState();
}

class _PedidoAcompanhamentoPageState extends State<PedidoAcompanhamentoPage>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    pedidoCtrl.onInitPage(FirestoreClient.pedidos.getById(widget.id));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamOut(
      stream: pedidoCtrl.pedidoStream.listen,
      builder: (_, pedido) {
        final String waNumber = PreferencesService.whatsappSuporte.value;
        final String waMessage = Uri.encodeComponent(
          'Olá, gostaria de informações sobre meu pedido ${pedido.localizador}',
        );
        final String waUrl = 'https://wa.me/$waNumber?text=$waMessage';

        return AppScaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: Text(
              'Acompanhamento de Pedido',
              style: AppCss.largeBold.setColor(AppColors.white),
            ),
            backgroundColor: AppColors.primaryMain,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildHeader(pedido),
                    Positioned(
                      bottom: -24,
                      left: 0,
                      right: 0,
                      child: _buildStatusCard(pedido),
                    ),
                  ],
                ),
                const SizedBox(height: 48), // Espaço para compensar a sobreposição
                _buildTimelineSection(pedido),
                _buildProductsSection(pedido),
                const SizedBox(height: 100), // Espaço para o botão flutuante
              ],
            ),
          ),
          fab: waNumber.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: () => launchUrlString(waUrl),
                  backgroundColor: const Color(0xFF25D366),
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  label: const Text(
                    'PRECISA DE AJUDA? FALE CONOSCO',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildHeader(PedidoModel pedido) {
    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 56), // Padding bottom maior para dar altura
      decoration: BoxDecoration(
        color: AppColors.primaryMain,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: LogoHelper.logoWidget(height: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Olá, ${pedido.cliente.nome.split(' ').first}!',
            style: AppCss.largeBold.setColor(Colors.white).setSize(20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Acompanhe o progresso do seu pedido',
            style: AppCss.mediumRegular.setColor(Colors.white.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(PedidoModel pedido) {
    final bool isLate = pedido.deliveryAt != null && pedido.deliveryAt!.isBefore(DateTime.now().subtract(const Duration(days: 1)));
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('LOCALIZADOR', style: AppCss.minimumBold.setColor(Colors.grey[500]!)),
                  Text(pedido.localizador, style: AppCss.largeBold.setSize(18)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isLate ? Colors.red[50]! : Colors.blue[50]!),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pedido.step.name.toUpperCase(),
                  style: AppCss.minimumBold.setColor(isLate ? Colors.red[800]! : Colors.blue[800]!),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 18, color: isLate ? Colors.red : Colors.grey[600]!),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLate ? 'PEDIDO EM ATRASO' : 'PREVISÃO DE ENTREGA',
                      style: AppCss.minimumBold.setColor(isLate ? Colors.red : Colors.grey[500]!),
                    ),
                    Text(
                      pedido.deliveryAt?.text() ?? 'A definir',
                      style: AppCss.mediumBold.setSize(16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(PedidoModel pedido) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Text('LINHA DO TEMPO', style: AppCss.mediumBold.setSize(14).setColor(AppColors.secondary)),
          ),
          PedidoTrackerTimelineWidget(pedido: pedido),
        ],
      ),
    );
  }

  Widget _buildProductsSection(PedidoModel pedido) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DETALHES DO PEDIDO', style: AppCss.mediumBold.setSize(14).setColor(AppColors.secondary)),
          const SizedBox(height: 16),
          ...pedido.produtos.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${p.qtde.round()}',
                      style: AppCss.smallBold.setColor(AppColors.primaryMain),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.produto.descricao, style: AppCss.smallBold),
                      Text('${p.qtde.toStringAsFixed(2)} Kg', style: AppCss.minimumRegular.setColor(Colors.grey[600]!)),
                    ],
                  ),
                ),
              ],
            ),
          )),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PESO TOTAL:', style: AppCss.smallBold),
              Text('${pedido.pesoTotal.toStringAsFixed(2)} Kg', style: AppCss.mediumBold.setColor(AppColors.primaryMain)),
            ],
          )
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
