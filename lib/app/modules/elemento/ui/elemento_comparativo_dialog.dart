import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/elemento/elemento_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showElementoComparativoDialog(
  BuildContext context, {
  required ElementoValidacaoResult validacao,
}) {
  return showDialog(
    context: context,
    builder: (_) => ElementoComparativoDialog(validacao: validacao),
  );
}

class ElementoComparativoDialog extends StatelessWidget {
  final ElementoValidacaoResult validacao;
  const ElementoComparativoDialog({required this.validacao, super.key});

  String _fmt(double v) => NumberFormat('#,##0.000', 'pt_BR').format(v);

  @override
  Widget build(BuildContext context) {
    final ok = validacao.isOk;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: ok ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            ok ? 'Comparativo OK' : 'Divergência de Pesos',
            style: AppCss.largeBold.copyWith(
              color: ok ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ok
                  ? 'O somatório dos pesos dos elementos coincide com o total planejado no pedido.'
                  : 'O somatório dos pesos dos elementos difere do total planejado no pedido.',
              style: AppCss.mediumRegular.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _TotalBox(
                    label: 'Total Pedido',
                    value: '${_fmt(validacao.totalPedidoKg)} kg',
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TotalBox(
                    label: 'Total Elementos',
                    value: '${_fmt(validacao.totalElementosKg)} kg',
                    color: ok ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (validacao.divergencias.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Divergências por Bitola:',
                style: AppCss.mediumBold.copyWith(color: Colors.red.shade700),
              ),
              const SizedBox(height: 8),
              Container(
                maxHeight: 200,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: validacao.divergencias.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.red.shade100),
                  itemBuilder: (_, i) {
                    final d = validacao.divergencias[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.produto.produto.labelMinified,
                          style: AppCss.smallBold.copyWith(color: Colors.red.shade900),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Esperado: ${_fmt(d.esperadoKg)} kg', style: AppCss.smallRegular),
                            Text('Calculado: ${_fmt(d.calculadoKg)} kg', style: AppCss.smallRegular),
                          ],
                        ),
                        Text(
                          'Diferença: ${_fmt(d.diferencaKg)} kg',
                          style: AppCss.smallBold.copyWith(color: Colors.red),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Fechar',
            style: AppCss.mediumBold.setColor(AppColors.primaryMain),
          ),
        ),
      ],
    );
  }
}

class _TotalBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TotalBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: AppCss.smallRegular.copyWith(color: color, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: AppCss.largeBold.copyWith(color: color, fontSize: 16)),
        ],
      ),
    );
  }
}
