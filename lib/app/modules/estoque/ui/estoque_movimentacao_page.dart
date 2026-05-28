import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/modules/estoque/ui/estoque_movimentacao_section.dart';
import 'package:flutter/material.dart';

class EstoqueMovimentacaoPage extends StatefulWidget {
  const EstoqueMovimentacaoPage({super.key});

  @override
  State<EstoqueMovimentacaoPage> createState() =>
      _EstoqueMovimentacaoPageState();
}

class _EstoqueMovimentacaoPageState extends State<EstoqueMovimentacaoPage> {
  @override
  void initState() {
    setWebTitle('Movimentação de Estoque');
    estoqueCtrl.onInit();
    BackendClient.estoquesMovimentacao.fetch();
    super.initState();
  }

  @override
  Widget build(BuildContext context) =>
      const EstoqueMovimentacaoSection();
}
