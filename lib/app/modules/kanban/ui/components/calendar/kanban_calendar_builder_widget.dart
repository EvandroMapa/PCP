import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/card/kanban_card_mouse_region_calendar_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:separated_column/separated_column.dart';
import 'package:table_calendar/table_calendar.dart';

class KanbanCalendarBuilderWidget extends StatefulWidget {
  const KanbanCalendarBuilderWidget({
    super.key,
    required this.day,
    required this.pedidos,
    required this.backgroundColor,
    required this.calendarFormat,
    required this.utils,
    this.hoje = false,
  });

  final DateTime day;
  final List<PedidoModel> pedidos;
  final Color backgroundColor;
  final CalendarFormat calendarFormat;
  final KanbanUtils utils;
  final bool hoje;
  @override
  State<KanbanCalendarBuilderWidget> createState() =>
      _KanbanCalendarBuilderWidgetState();
}

class _KanbanCalendarBuilderWidgetState
    extends State<KanbanCalendarBuilderWidget> {
  final ScrollController _scrollController = ScrollController();

  /// "4 · 12,3 t" (só os pedidos que passam no filtro)
  String _resumo() {
    final visiveis =
        widget.pedidos.where(widget.utils.isPedidoVisibleFiltered).toList();
    if (visiveis.isEmpty) return '';
    final kg = visiveis.fold(0.0, (s, p) => s + p.getQtdeTotal());
    final peso = kg >= 1000
        ? '${(kg / 1000).toStringAsFixed(1).replaceAll('.', ',')} t'
        : '${kg.round()} kg';
    return '${visiveis.length} · $peso';
  }

  @override
  Widget build(BuildContext context) {
    final resumo = _resumo();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: Border.all(
          color: const Color.fromARGB(
            255,
            209,
            210,
            214,
          ).withValues(alpha: 0.8),
          width: 0.25,
        ),
      ),
      width: double.maxFinite,
      child: Scrollbar(
        controller: _scrollController,
        child: ListView(
          controller: _scrollController,
          physics: widget.pedidos.isEmpty
              ? const NeverScrollableScrollPhysics()
              : null,
          children: [
            Stack(
              children: [
                if (resumo.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      resumo,
                      style: AppCss.minimumBold.copyWith(
                        color: AppColors.neutralDark,
                        fontSize: 10.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    DateFormat('d').format(widget.day),
                    style: AppCss.minimumRegular.copyWith(
                      color: widget.hoje ? AppColors.brand : Colors.grey[900],
                      fontWeight: FontWeight.bold,
                      fontSize: widget.hoje ? 13 : 11,
                      height: 1.2,
                    ),
                  ),
                ),
                if (widget.pedidos.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () =>
                          kanbanCtrl.setDay({widget.day: widget.pedidos}),
                      child: Icon(
                        Icons.fullscreen,
                        size: 16,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
              ],
            ),
            const H(8),
            if (widget.pedidos.isNotEmpty)
              SeparatedColumn(
                separatorBuilder: (_, __) => const H(8),
                children: widget.pedidos
                    .map(
                      (e) => widget.utils.isPedidoVisibleFiltered(e)
                          ? KanbanCardMouseRegionCalendarWidget(
                              e,
                              calendarFormat: widget.calendarFormat,
                            )
                          : const SizedBox(),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
