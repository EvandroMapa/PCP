import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/modules/estoque/ui/estoque_saldo_section.dart';
import 'package:flutter/material.dart';

class EstoqueSaldoPage extends StatefulWidget {
  const EstoqueSaldoPage({super.key});

  @override
  State<EstoqueSaldoPage> createState() => _EstoqueSaldoPageState();
}

class _EstoqueSaldoPageState extends State<EstoqueSaldoPage> {
  @override
  void initState() {
    setWebTitle('Estoque - Saldos');
    estoqueCtrl.onInit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) => const EstoqueSaldoSection();
}
