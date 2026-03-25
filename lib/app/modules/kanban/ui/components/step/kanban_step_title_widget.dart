import 'package:aco_plus/app/modules/pedido/ui/pedido_import_pdf_dialog.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:flutter/material.dart';

class KanbanStepTitleWidget extends StatelessWidget {
...
          IconButton(
            onPressed: () async {
              final files = await showPedidoImportPdfDialog();
              if (files != null && files.isNotEmpty) {
                NotificationService.showPositive(
                  'Sucesso',
                  '${files.length} arquivo(s) selecionado(s) para importação.',
                );
              }
            },
            icon: const Icon(Icons.add, color: Colors.blue, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Importar Pedidos (PDF)',
          ),
          PopupMenuButton<SortStepType?>(
            style: ButtonStyle(
              padding: WidgetStateProperty.all(EdgeInsets.zero),
              fixedSize: WidgetStateProperty.all(const Size(24, 24)),
              minimumSize: WidgetStateProperty.all(const Size(24, 24)),
            ),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, size: 18),
            surfaceTintColor: Colors.white,
            color: Colors.white,
            onSelected: (e) => kanbanCtrl.onOrderPedidos(e, pedidos),
            itemBuilder: (context) => [
              PopupMenuItem(
                height: 32,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ordenação',
                        style: AppCss.minimumBold.setSize(14),
                      ),
                    ),
                    const Icon(Icons.close, color: Colors.black, size: 14),
                  ],
                ),
              ),
              ...SortStepType.values.map(
                (e) => PopupMenuItem(
                  height: 32,
                  value: e,
                  child: Text(
                    e.label,
                    style: AppCss.minimumRegular.setSize(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: Text(step.name, style: AppCss.minimumBold)),
                if (!step.isEnable)
                  Container(
                    margin: const EdgeInsets.only(left: 4),
                    child: const Icon(Icons.lock, color: Colors.red, size: 12),
                  ),
              ],
            ),
          ),
          Text(
            pedidos
                .where((e) => utils.isPedidoVisibleFiltered(e))
                .map((e) => e.getQtdeTotal())
                .fold(.0, (a, b) => a + b)
                .toKg(),
            style: AppCss.minimumRegular,
          ),
        ],
      ),
      onExpansionChanged: (e) {},
      children: const <Widget>[],
    );
  }
}
