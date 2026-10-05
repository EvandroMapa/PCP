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
    if (this == AppModule.kanban ||
        this == AppModule.dashboard ||
        this == AppModule.painelGerencial) {
      return PreferredSize(
        preferredSize: Size.zero,
        child: SizedBox.shrink(),
      );
    }
    return null;
  }

  /// Um ícone diferente por item (Material Symbols, mesmo traço em todos).
  IconData get icon {
    switch (this) {
      case AppModule.dashboard:
        return Symbols.space_dashboard;
      case AppModule.cliente:
        return Symbols.groups;
      case AppModule.pedidos:
        return Symbols.list_alt;
      case AppModule.ordens:
        return Symbols.assignment;
      case AppModule.relatoriosProducao:
        return Symbols.analytics;
      case AppModule.estoqueRelatorio:
        return Symbols.inventory;
      case AppModule.planoCorte:
        return Symbols.content_cut;
      case AppModule.steps:
        return Symbols.linear_scale;
      case AppModule.tags:
        return Symbols.sell;
      case AppModule.kanban:
        return Symbols.view_kanban;
      case AppModule.fabricantes:
        return Symbols.apartment;
      case AppModule.produtos:
        return Symbols.stacks;
      case AppModule.materiaPrima:
        return Symbols.forklift;
      case AppModule.pontas:
        return Symbols.straighten;
      case AppModule.armacao:
        return Symbols.construction;
      case AppModule.estoqueSaldo:
        return Symbols.inventory_2;
      case AppModule.estoqueMovimentacao:
        return Symbols.swap_vert;
      case AppModule.pedidoCompra:
        return Symbols.shopping_cart;
      case AppModule.painelGerencial:
        return Symbols.monitoring;
      case AppModule.equipamentos:
        return Symbols.precision_manufacturing;
    }
  }

  String get label {
    switch (this) {
      case AppModule.dashboard:
        return 'Gestão à Vista';
      case AppModule.cliente:
        return 'Clientes';
      case AppModule.pedidos:
        return 'Lista de pedidos';
      case AppModule.ordens:
        return 'Ordens de produção';
      case AppModule.relatoriosProducao:
        return 'Relatórios';
      case AppModule.estoqueRelatorio:
        return 'Posição de estoque';
      case AppModule.planoCorte:
        return 'Plano de corte';
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
        return 'Matéria-prima';
      case AppModule.pontas:
        return 'Pontas';
      case AppModule.armacao:
        return 'Armação';
      case AppModule.estoqueSaldo:
        return 'Saldos de estoque';
      case AppModule.estoqueMovimentacao:
        return 'Movimentações';
      case AppModule.pedidoCompra:
        return 'Pedidos de compra';
      case AppModule.painelGerencial:
        return 'Painel gerencial';
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
