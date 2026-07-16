import 'package:aco_plus/app/modules/armacao/ui/armacao_page.dart';
import 'package:aco_plus/app/modules/cliente/ui/clientes_page.dart';
import 'package:aco_plus/app/modules/dashboard/ui/dashboard_page.dart';
import 'package:aco_plus/app/modules/fabricante/ui/fabricantes_page.dart';
import 'package:aco_plus/app/modules/kanban/ui/kanban_page.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materias_primas_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordens_page.dart';
import 'package:aco_plus/app/modules/painel_gerencial/ui/painel_gerencial_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedidos_page.dart';
import 'package:aco_plus/app/modules/bitola/ui/bitolas_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/estoque/relatorios_estoque_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/plano_corte/planos_corte_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/relatorios_producao_page.dart';
import 'package:aco_plus/app/modules/ponta/ui/pontas_page.dart';
import 'package:aco_plus/app/modules/step/ui/steps_page.dart';
import 'package:aco_plus/app/modules/tag/ui/tags_page.dart';
import 'package:aco_plus/app/modules/estoque/ui/estoque_movimentacao_page.dart';
import 'package:aco_plus/app/modules/estoque/ui/estoque_page.dart';
import 'package:aco_plus/app/modules/pedido_compra/ui/pedido_compra_page.dart';
import 'package:aco_plus/app/modules/equipamento/ui/equipamentos_page.dart';


import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum AppModule {
  dashboard,
  kanban,
  pedidos,
  ordens,
  relatoriosProducao,
  estoqueRelatorio,
  planoCorte,
  cliente,
  steps,
  tags,
  fabricantes,
  produtos,
  materiaPrima,
  pontas,
  armacao,
  estoqueSaldo,
  estoqueMovimentacao,
  pedidoCompra,
  painelGerencial,
  equipamentos,
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
      case AppModule.relatoriosProducao:
        return const RelatoriosProducaoPage();
      case AppModule.estoqueRelatorio:
        return const RelatoriosEstoquePage();
      case AppModule.planoCorte:
        return const PlanosCortePage();
      case AppModule.steps:
        return const StepsPage();
      case AppModule.tags:
        return const TagsPage();
      case AppModule.kanban:
        return const KanbanPage();
      case AppModule.fabricantes:
        return const FabricantesPage();
      case AppModule.produtos:
        return const BitolasPage();
      case AppModule.materiaPrima:
        return const MateriasPrimasPage();
      case AppModule.pontas:
        return const PontasPage();
      case AppModule.armacao:
        return const ArmacaoPage();
      case AppModule.estoqueSaldo:
        return const EstoquePage();
      case AppModule.estoqueMovimentacao:
        return const EstoqueMovimentacaoPage();
      case AppModule.pedidoCompra:
        return const PedidoCompraPage();
      case AppModule.painelGerencial:
        return const PainelGerencialPage();
      case AppModule.equipamentos:
        return const EquipamentosPage();

    }
  }

  PreferredSizeWidget? appBar(BuildContext context) {
    if (this == AppModule.kanban || this == AppModule.dashboard || this == AppModule.painelGerencial) {
      return PreferredSize(
        preferredSize: Size.zero,
        child: SizedBox.shrink(),
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
      case AppModule.relatoriosProducao:
        return Icons.assessment_outlined;
      case AppModule.estoqueRelatorio:
        return Icons.inventory_2_outlined;
      case AppModule.planoCorte:
        return Icons.content_cut;
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
      case AppModule.pontas:
        return Icons.flip_to_back;
      case AppModule.armacao:
        return Icons.iron_rounded;
      case AppModule.estoqueSaldo:
        return Icons.inventory_2_outlined;
      case AppModule.estoqueMovimentacao:
        return Icons.swap_vert_outlined;
      case AppModule.pedidoCompra:
        return Icons.shopping_cart_outlined;
      case AppModule.painelGerencial:
        return Icons.phone_android;
      case AppModule.equipamentos:
        return Icons.precision_manufacturing_outlined;

    }
  }

  String get label {
    switch (this) {
      case AppModule.dashboard:
        return 'Gestão a Vista';
      case AppModule.cliente:
        return 'Clientes';
      case AppModule.pedidos:
        return 'Listagem';
      case AppModule.ordens:
        return 'Ordens de Produção';
      case AppModule.relatoriosProducao:
        return 'Relatórios';
      case AppModule.estoqueRelatorio:
        return 'Posição de Estoque';
      case AppModule.planoCorte:
        return 'Plano de Corte';
      case AppModule.steps:
        return 'Etapas';
      case AppModule.kanban:
        return 'Kanban';
      case AppModule.tags:
        return 'Etiquetas';
      case AppModule.fabricantes:
        return 'Fabricantes';
      case AppModule.produtos:
        return 'Bitolas';
      case AppModule.materiaPrima:
        return 'Matéria Prima';
      case AppModule.pontas:
        return 'Cadastro de Pontas';
      case AppModule.armacao:
        return 'Armação';
      case AppModule.estoqueSaldo:
        return 'Painel';
      case AppModule.estoqueMovimentacao:
        return 'Movimentação de Estoque';
      case AppModule.pedidoCompra:
        return 'Pedidos de Compra';
      case AppModule.painelGerencial:
        return 'Painel Gerencial';
      case AppModule.equipamentos:
        return 'Equipamentos';

    }
  }

  /// Retorna o path standalone para abrir em nova aba, ou null se não suportado.
  String? get standalonePath {
    switch (this) {
      case AppModule.painelGerencial:
        return '/gerencial';
      default:
        return null;
    }
  }
}
