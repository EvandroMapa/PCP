import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

class PedidoProgressoWidget extends StatelessWidget {
  final PedidoModel pedido;
  const PedidoProgressoWidget({required this.pedido, super.key});

  @override
  Widget build(BuildContext context) {
    // --- CÁLCULO CORTE E DOBRA (CD) ---
    double cdTotal = pedido.getQtdeTotal();
    double cdPronto = pedido.getQtdePronto();

    // Adicionar posições dos elementos ao Corte e Dobra
    for (final e in pedido.elementos) {
      for (final pos in e.posicoes) {
        final double pesoPosicaoTotal = pos.pesoKg * e.qtde;
        cdTotal += pesoPosicaoTotal;
        if (pos.status == PosicaoStatus.pronto) {
          cdPronto += pesoPosicaoTotal;
        }
      }
    }
    final double cdPercent = cdTotal > 0 ? (cdPronto / cdTotal) : 0.0;

    // --- CÁLCULO ARMAÇÃO (CDA) ---
    final double cdaTotal =
        pedido.elementos.fold(0.0, (sum, e) => sum + e.pesoTotal);
    final double cdaPronto =
        pedido.elementos.fold(0.0, (sum, e) => sum + e.pesoPronto);
    final double cdaPercent = cdaTotal > 0 ? (cdaPronto / cdaTotal) : 0.0;

    final bool isCDA = pedido.tipo == PedidoTipo.cda;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROGRESSO DA PRODUÇÃO',
            style: AppCss.mediumBold.setSize(14).setColor(AppColors.secondary),
          ),
          const SizedBox(height: 20),

          // Barra de Corte e Dobra
          _buildProgressBar(
            label: 'CORTE E DOBRA',
            percent: cdPercent,
            total: cdTotal,
            pronto: cdPronto,
            color: const Color(0xFF3B82F6), // Azul
          ),

          if (isCDA && cdaTotal > 0) ...[
            const SizedBox(height: 24),
            // Barra de Armação
            _buildProgressBar(
              label: 'ARMAÇÃO',
              percent: cdaPercent,
              total: cdaTotal,
              pronto: cdaPronto,
              color: const Color(0xFFFACC15), // Amarelo/Dourado Premium
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar({
    required String label,
    required double percent,
    required double total,
    required double pronto,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppCss.minimumBold.setColor(Colors.grey[600]!),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${(percent * 100).toStringAsFixed(0)}%',
                    style: AppCss.smallBold.setColor(color),
                  ),
                  TextSpan(
                    text:
                        ' (${pronto.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} Kg)',
                    style: AppCss.minimumRegular.setColor(Colors.grey[500]!),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              height: 12,
              width: double.maxFinite,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              height: 12,
              width: (percent * 1000).clamp(0.0, 1000.0) /
                  1000 *
                  1, // Placeholder for actual width calculation
              // Note: Using LayoutBuilder for precise width or just FractionallySizedBox
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percent.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
