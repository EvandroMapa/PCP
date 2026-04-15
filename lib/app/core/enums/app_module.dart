import 'package:aco_plus/app/modules/armacao/ui/armacao_page.dart';
import 'package:aco_plus/app/modules/cliente/ui/clientes_page.dart';
import 'package:aco_plus/app/modules/dashboard/ui/dashboard_page.dart';
import 'package:aco_plus/app/modules/fabricante/ui/fabricantes_page.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/kanban/kanban_top_bar_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/kanban_page.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materias_primas_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordens_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedidos_page.dart';
import 'package:aco_plus/app/modules/produto/ui/produtos_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/ordem/relatorios_ordem_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/pedido/relatorios_pedido_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/producao/relatorios_producao_page.dart';
import 'package:aco_plus/app/modules/step/ui/steps_page.dart';
import 'package:aco_plus/app/modules/tag/ui/tags_page.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum AppModule {
  dashboard,
  kanban,
  pedidos,
  ordens,
  pedidoRelatorio,
  ordemRelatorio,
  producaoRelatorio,
  cliente,
  steps,
  tags,
  fabricantes,
  produtos,
  materiaPrima,
  armacao,
}

extension AppModuleExt on AppModule {
  Widget get widget {
    switch (this) {
      case AppModule.dashboard:
        return const DashboardPage();
      case AppModule.cliente:
        return const ClientesPage();
      case AppModule.pedidos:
        return const PedidosPage();
      case AppModule.ordens:
        return const OrdensPage();
      case AppModule.pedidoRelatorio:
        return const RelatoriosPedidoPage();
      case AppModule.ordemRelatorio:
        return const RelatoriosOrdemPage();
      case AppModule.producaoRelatorio:
        return const RelatoriosProducaoPage();
      case AppModule.steps:
        return const StepsPage();
      case AppModule.tags:
        return const TagsPage();
      case AppModule.kanban:
        return const KanbanPage();
      case AppModule.fabricantes:
        return const FabricantesPage();
      case AppModule.produtos:
        return const ProdutosPage();
      case AppModule.materiaPrima:
        return const MateriasPrimasPage();
      case AppModule.armacao:
        return const ArmacaoPage();
    }
  }

  PreferredSizeWidget? appBar(BuildContext context) {
    if (this == AppModule.kanban) {
      return const KanbanTopBarWidget();
    }
    if (this == AppModule.dashboard) {
      return AppBar(
        iconTheme: const IconThemeData(color: Colors.white, size: 20),
        backgroundColor: AppColors.primaryMain,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gestão a Vista',
                style: AppCss.mediumBold.setSize(20).setColor(Colors.white)),
            Text('Monitoramento em tempo real de produção e consumo',
                style: AppCss.minimumRegular
                    .setSize(12)
                    .setColor(Colors.white.withOpacity(0.8))),
          ],
        ),
      );
    }
    return null;
  }

  IconData get icon {
    switch (this) {
      case AppModule.dashboard:
        return Icons.dashboard_outlined;
      case AppModule.cliente:
        return Icons.group_outlined;
      case AppModule.pedidos:
        return Icons.shopping_cart_outlined;
      case AppModule.ordens:
        return (usuarioCtrl.usuario?.isNotOperador ?? false)
            ? Icons.list
            : Icons.work_outline;
      case AppModule.pedidoRelatorio:
        return Icons.shopping_cart_outlined;
      case AppModule.ordemRelatorio:
        return Icons.work_outline;
      case AppModule.producaoRelatorio:
        return Icons.timer_outlined;
      case AppModule.steps:
        return Icons.list_alt_outlined;
      case AppModule.tags:
        return Icons.label_outlined;
      case AppModule.kanban:
        return Symbols.view_kanban;
      case AppModule.fabricantes:
        return Icons.business_outlined;
      case AppModule.produtos:
        return Icons.inventory_2_outlined;
      case AppModule.materiaPrima:
        return Icons.warehouse_outlined;
      case AppModule.armacao:
        return Icons.iron_rounded;
    }
  }

  String get label {
    switch (this) {
      case AppModule.dashboard:
        return 'Gestão a Vista';
      case AppModule.cliente:
        return 'Clientes';
      case AppModule.pedidos:
        return 'Pedidos';
      case AppModule.ordens:
        return 'Ordens de Produção';
      case AppModule.ordemRelatorio:
        return 'Ordens de Produção';
      case AppModule.pedidoRelatorio:
        return 'Relatório de Consumo';
      case AppModule.producaoRelatorio:
        return 'Produção';
      case AppModule.steps:
        return 'Etapas';
      case AppModule.kanban:
        return 'Kanban';
      case AppModule.tags:
        return 'Etiquetas';
      case AppModule.fabricantes:
        return 'Fabricantes';
      case AppModule.produtos:
        return 'Produtos';
      case AppModule.materiaPrima:
        return 'Materia Prima';
      case AppModule.armacao:
        return 'Armação';
    }
  }

  /// Retorna o path standalone para abrir em nova aba, ou null se não suportado.
  String? get standalonePath {
    switch (this) {
      case AppModule.kanban:
        return '/kanban';
      case AppModule.pedidos:
        return '/pedidos';
      case AppModule.ordens:
        return '/ordens';
      default:
        return null;
    }
  }
}
