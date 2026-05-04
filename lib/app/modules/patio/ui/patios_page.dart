import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/patio/patio_controller.dart';
import 'package:aco_plus/app/modules/patio/patio_view_model.dart';
import 'package:aco_plus/app/modules/patio/ui/patio_create_page.dart';
import 'package:flutter/material.dart';

class PatiosPage extends StatefulWidget {
  const PatiosPage({super.key});

  @override
  State<PatiosPage> createState() => _PatiosPageState();
}

class _PatiosPageState extends State<PatiosPage> {
  @override
  void initState() {
    setWebTitle('Pátios');
    patioCtrl.onInit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          'Pátios',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          IconButton(
            onPressed: () => push(context, const PatioCreatePage()),
            icon: const Icon(Icons.add, color: Colors.white),
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut<List<PatioModel>>(
        stream: FirestoreClient.patios.dataStream.listen,
        builder: (_, __) => StreamOut<PatioUtils>(
          stream: patioCtrl.utilsStream.listen,
          builder: (_, utils) {
            final patios =
                patioCtrl.getPatiosFiltered(utils.search.text, __).toList();
            patios.sort(
                (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppField(
                    hint: 'Pesquisar',
                    controller: utils.search,
                    suffixIcon: Icons.search,
                    onChanged: (_) => patioCtrl.utilsStream.update(),
                  ),
                ),
                Expanded(
                  child: patios.isEmpty
                      ? const EmptyData()
                      : RefreshIndicator(
                          onRefresh: () async =>
                              FirestoreClient.patios.fetch(),
                          child: ListView.builder(
                            itemCount: patios.length,
                            itemBuilder: (_, i) =>
                                _itemPatioWidget(patios[i]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _itemPatioWidget(PatioModel patio) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: ListTile(
        onTap: () => push(context, PatioCreatePage(patio: patio)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryMain.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.grid_view_rounded,
            color: AppColors.primaryMain,
            size: 18,
          ),
        ),
        title: Text(patio.nome, style: AppCss.mediumBold),
        subtitle: Text(
          '${patio.comprimento}m × ${patio.largura}m',
          style: AppCss.minimumRegular.setColor(AppColors.neutralMedium),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon:
                  Icon(Icons.edit_outlined, color: Colors.blue[600], size: 16),
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () =>
                  push(context, PatioCreatePage(patio: patio)),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: Colors.red[600], size: 16),
              iconSize: 16,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              onPressed: () => patioCtrl.onDelete(context, patio),
            ),
          ],
        ),
      ),
    );
  }
}
