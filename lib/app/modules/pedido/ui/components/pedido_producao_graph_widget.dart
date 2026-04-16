import 'dart:math';

import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

/// Modelo de dados para cada bolinha do gráfico de produção.
class ProducaoGraphData {
  final String label;
  final double pesoKg;
  final double percentual; // 0.0 a 1.0
  final Color color;

  ProducaoGraphData({
    required this.label,
    required this.pesoKg,
    required this.percentual,
    required this.color,
  });
}

/// Três bolinhas de progresso lado a lado: Aguardando / Produzindo|Armando / Pronto.
class PedidoProducaoGraphWidget extends StatelessWidget {
  final List<ProducaoGraphData> data;
  final double totalKg;

  const PedidoProducaoGraphWidget({
    required this.data,
    required this.totalKg,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || totalKg <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Sem dados de produção',
            style: AppCss.minimumRegular.copyWith(color: Colors.grey[400]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: data
            .map((d) => _DonutItem(data: d))
            .toList(),
      ),
    );
  }
}

class _DonutItem extends StatelessWidget {
  final ProducaoGraphData data;
  const _DonutItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = (data.percentual * 100).toStringAsFixed(0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: CustomPaint(
            painter: _RingPainter(
              progress: data.percentual,
              color: data.color,
            ),
            child: Center(
              child: Text(
                '$pct%',
                style: AppCss.minimumBold.copyWith(
                  fontSize: 14,
                  color: data.color,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.label,
          style: AppCss.minimumRegular.copyWith(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0.0 a 1.0
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;
    const strokeWidth = 7.0;

    // Fundo (trilha cinza)
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progresso
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // início no topo
        2 * pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
