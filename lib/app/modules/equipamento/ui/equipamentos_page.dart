import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/equipamento/equipamento_controller.dart';
import 'package:aco_plus/app/modules/equipamento/equipamento_view_model.dart';
import 'package:aco_plus/app/modules/equipamento/ui/equipamento_create_page.dart';
import 'package:flutter/material.dart';

class EquipamentosPage extends StatefulWidget {
  const EquipamentosPage({super.key});

  @override
  State<EquipamentosPage> createState() => _EquipamentosPageState();
}

class _EquipamentosPageState extends State<EquipamentosPage> {
  @override
  void initState() {
    setWebTitle('Equipamentos');
    FirestoreClient.equipamentos.fetch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add(<Widget>[
        IconButton(
          onPressed: () => push(context, const EquipamentoCreatePage()),
          icon: const Icon(Icons.add, color: Colors.white),
        ),
      ]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<EquipamentoModel>>(
      stream: FirestoreClient.equipamentos.dataStream.listen,
      builder: (_, __) => StreamOut<EquipamentoUtils>(
        stream: equipamentoCtrl.utilsStream.listen,
        builder: (_, utils) {
          final equipamentos = equipamentoCtrl
              .getEquipamentosFiltered(utils.search.text, __)
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppField(
                  hint: 'Pesquisar',
                  controller: utils.search,
                  suffixIcon: Icons.search,
                  onChanged: (_) => equipamentoCtrl.utilsStream.update(),
                ),
              ),
              Expanded(
                child: equipamentos.isEmpty
                    ? const EmptyData()
                    : ListView.builder(
                        itemCount: equipamentos.length,
                        itemBuilder: (_, i) =>
                            _itemEquipamentoWidget(equipamentos[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _itemEquipamentoWidget(EquipamentoModel equipamento) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: ListTile(
        onTap: () =>
            push(context, EquipamentoCreatePage(equipamento: equipamento)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryMain.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.precision_manufacturing_outlined,
              color: AppColors.primaryMain, size: 20),
        ),
        title: Text(equipamento.descricao, style: AppCss.mediumBold),
        subtitle: equipamento.codigo.isNotEmpty
            ? Text('Código: ${equipamento.codigo}')
            : null,
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: AppColors.neutralMedium,
        ),
      ),
    );
  }
}
