import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/relatorio/ui/arvore/arvore_producao_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/ordem/relatorios_ordem_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/pedido/relatorios_pedido_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/produtividade/relatorio_produtividade_page.dart';
import 'package:flutter/material.dart';

class RelatoriosProducaoPage extends StatefulWidget {
  const RelatoriosProducaoPage({super.key});

  @override
  State<RelatoriosProducaoPage> createState() =>
      _RelatoriosProducaoPageState();
}

class _RelatoriosProducaoPageState extends State<RelatoriosProducaoPage> {
  int _selected = 0;

  @override
  void initState() {
    setWebTitle('AçoPlus - Relatórios de Produção');
    super.initState();
  }

  final _menuItems = const [
    (Icons.shopping_cart_outlined, 'Consumo Previsto'),
    (Icons.assessment_outlined, 'Produtividade'),
    (Icons.work_outline, 'Ordens de Produção'),
    (Icons.account_tree_outlined, 'Árvore de Produção'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _sidebar(),
        const VerticalDivider(
            width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          ? AppColors.primaryMain
                              .withValues(alpha: 0.10)
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryMain
                                .withValues(alpha: 0.20)
                            : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      item.$1,
                      size: 18,
                      color: selected
                          ? AppColors.primaryMain
                          : Colors.grey[400],
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
        return const RelatoriosPedidoPage();
      case 1:
        return const RelatorioProdutividadePage();
      case 2:
        return const RelatoriosOrdemPage();
      case 3:
        return const ArvoreProducaoPage();
      default:
        return const RelatoriosPedidoPage();
    }
  }
}
