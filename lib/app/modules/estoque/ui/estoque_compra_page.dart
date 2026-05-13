import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/modules/estoque/ui/estoque_compra_section.dart';
import 'package:flutter/material.dart';

class EstoqueCompraPage extends StatefulWidget {
  const EstoqueCompraPage({super.key});

  @override
  State<EstoqueCompraPage> createState() => _EstoqueCompraPageState();
}

class _EstoqueCompraPageState extends State<EstoqueCompraPage> {
  @override
  void initState() {
    setWebTitle('Estoque - Compras');
    estoqueCtrl.onInit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) => const EstoqueCompraSection();
}
