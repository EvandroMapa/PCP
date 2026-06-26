import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/modules/estoque/estoque_view_model.dart';
import 'package:aco_plus/app/modules/estoque/ui/estoque_grafico_section.dart';
import 'package:aco_plus/app/modules/estoque/ui/estoque_movimentacao_section.dart';
import 'package:aco_plus/app/modules/estoque/ui/estoque_saldo_section.dart';
import 'package:aco_plus/app/modules/relatorio/ui/estoque/relatorios_estoque_page.dart';
import 'package:flutter/material.dart';

class EstoquePage extends StatefulWidget {
  const EstoquePage({super.key});

  @override
  State<EstoquePage> createState() => _EstoquePageState();
}

class _EstoquePageState extends State<EstoquePage> {
  int _selected = 0;

  @override
  void initState() {
    setWebTitle('Estoque');
    estoqueCtrl.onInit();
    super.initState();
  }

  final _menuItems = const [
    (Icons.inventory_2_outlined, 'Saldo'),
    (Icons.analytics_outlined, 'Posição'),
    (Icons.bar_chart_rounded, 'Gráfico'),
    (Icons.swap_vert_outlined, 'Movimentação'),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamOut<EstoqueUtils>(
      stream: estoqueCtrl.utilsStream.listen,
      builder: (_, __) => Row(
        children: [
          _sidebar(),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFF8FAFC),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_selected),
                  child: _sectionWidget(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 60,
      color: const Color(0xFFF1F5F9),
      child: Column(
        children: [
          const SizedBox(height: 8),
          ..._menuItems.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final selected = _selected == i;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Tooltip(
                message: item.$2,
                preferBelow: false,
                waitDuration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  onTap: () => setState(() => _selected = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryMain.withValues(alpha: 0.10)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryMain.withValues(alpha: 0.20)
                            : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.$1,
                      size: 18,
                      color: selected ? AppColors.primaryMain : Colors.grey[400],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionWidget() {
    switch (_selected) {
      case 0:
        return const EstoqueSaldoSection();
      case 1:
        return const RelatoriosEstoquePage();
      case 2:
        return const EstoqueGraficoSection();
      case 3:
        return const EstoqueMovimentacaoSection();
      default:
        return const EstoqueSaldoSection();
    }
  }
}
