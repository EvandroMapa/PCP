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
    final color = ok ? Colors.green : Colors.red;

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Icon(
              ok ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            ok ? 'Comparativo OK' : 'Divergência de Pesos',
            style: AppCss.largeBold.setSize(20).setColor(color.shade800),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ok
                  ? 'Excelente! O somatório dos elementos coincide perfeitamente com o total planejado no pedido.'
                  : 'Atenção! Foram encontradas divergências entre o planejado no pedido e a soma dos elementos cadastrados.',
              style: AppCss.mediumRegular.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _TotalBox(
                    label: 'TOTAL DO PEDIDO',
                    value: '${_fmt(validacao.totalPedidoKg)} kg',
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TotalBox(
                    label: 'TOTAL ELEMENTOS',
                    value: '${_fmt(validacao.totalElementosKg)} kg',
                    color: color,
                  ),
                ),
              ],
            ),
            if (validacao.divergencias.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.list_alt_rounded, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    'Divergências por Bitola:',
                    style: AppCss.mediumBold.setColor(Colors.red.shade700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: validacao.divergencias.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = validacao.divergencias[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                d.produto.produto.labelMinified,
                                style: AppCss.mediumBold.setColor(Colors.red.shade900),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Dif: ${_fmt(d.diferencaKg)} kg',
                                  style: AppCss.minimumBold.setColor(Colors.red.shade900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _miniLabel('Esperado', _fmt(d.esperadoKg)),
                              ),
                              Expanded(
                                child: _miniLabel('Calculado', _fmt(d.calculadoKg)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Fechar',
            style: AppCss.mediumBold.setColor(AppColors.primaryMain),
          ),
        ),
      ],
    );
  }

  Widget _miniLabel(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppCss.minimumRegular.copyWith(color: Colors.grey[500], fontSize: 10)),
        Text('$value kg', style: AppCss.smallBold.copyWith(color: Colors.grey[800])),
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label,
              style: AppCss.minimumBold.copyWith(
                color: color.withOpacity(0.6),
                letterSpacing: 0.5,
                fontSize: 10,
              )),
          const SizedBox(height: 6),
          Text(value,
              style: AppCss.largeBold.copyWith(
                color: color,
                fontSize: 18,
                letterSpacing: -0.5,
              )),
        ],
      ),
    );
  }
}
