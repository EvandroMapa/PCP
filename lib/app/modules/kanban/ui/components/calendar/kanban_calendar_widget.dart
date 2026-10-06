import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automatizacao_model.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/kanban/kanban_view_model.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/calendar/kanban_calendar_builder_widget.dart';
import 'package:aco_plus/app/modules/kanban/ui/components/calendar/kanban_calendar_weekday_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class KanbanCalendarWidget extends StatefulWidget {
  final KanbanUtils utils;
  final AutomatizacaoModel automatizacao;
  const KanbanCalendarWidget(this.utils, this.automatizacao, {super.key});

  @override
  State<KanbanCalendarWidget> createState() => _KanbanCalendarWidgetState();
}

class _KanbanCalendarWidgetState extends State<KanbanCalendarWidget> {
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    kanbanCtrl.onMountCalendar();
    super.initState();
  }

  DateTime getBorderDates({bool? first, bool? last}) {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, 1);
    final dates = [
      ...widget.utils.calendar.keys.toList().map(
            (e) => DateFormat('dd/MM/yyyy').parse(e),
          ),
      nowDate,
    ];
    dates.sort();
    if (first == true) return dates.first.subtract(const Duration(days: 100));
    if (last == true) return dates.last.add(const Duration(days: 100));
    throw Exception('Invalid border date');
  }

  List<PedidoModel> getPedidos(DateTime day) {
    final key = DateFormat('dd/MM/yyyy').format(day);
    final pedidosByDay = widget.utils.calendar[key] ?? [];
    if (pedidosByDay.isEmpty) return [];
    final steps = widget.automatizacao.naoMostrarNoCalendario.steps!
        .map((e) => e.id)
        .toList();
    final pedidosByMostramNoCalendario =
        pedidosByDay.where((e) => !steps.contains(e.step.id)).toList();
    return pedidosByMostramNoCalendario;
  }

  /// Mesma conta do filtro rápido "Sem data" (todas as etapas)
  List<PedidoModel> _semData() => BackendClient.pedidos.pepidosUnarchiveds
      .where((p) =>
          p.deliveryAt == null &&
          !p.isEntregue &&
          widget.utils.isPedidoVisibleFiltered(p))
      .toList();

  // ── Barra do calendário: Hoje, Atrasados, Sem data, Semanal/Mensal ──────
  Widget _barraCalendario() {
    final semData = _semData();
    final mensal = widget.utils.calendarFormat == CalendarFormat.month;

    Widget botao(String texto, IconData icon, VoidCallback onTap,
        {Color? cor}) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: cor ?? AppColors.black,
          backgroundColor: Colors.white,
          side: BorderSide(
              color: cor?.withValues(alpha: 0.5) ?? AppColors.neutralLight),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          visualDensity: VisualDensity.compact,
          textStyle: AppCss.minimumBold.setSize(12.5),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: Text(texto),
      );
    }

    Widget segmento(String texto, bool ativo, VoidCallback onTap) {
      return InkWell(
        onTap: ativo ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          color: ativo ? AppColors.primaryMain : Colors.white,
          child: Text(
            texto,
            style: AppCss.minimumBold
                .setSize(12.5)
                .setColor(ativo ? Colors.white : AppColors.neutralDark),
          ),
        ),
      );
    }

    void formato(CalendarFormat f) {
      kanbanCtrl.utils.calendarFormat = f;
      kanbanCtrl.utilsStream.update();
    }

    return Container(
      width: double.maxFinite,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.neutralLight)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              botao('Hoje', Icons.today, () {
                kanbanCtrl.utils.focusedDay = DateTime.now();
                kanbanCtrl.utilsStream.update();
              }),
              // Sem data não tem dia no calendário: aviso com a lista
              if (widget.utils.soSemData)
                botao(
                  'Pedidos sem data não aparecem no calendário · Ver lista (${semData.length})',
                  Icons.event_busy,
                  () => kanbanCtrl.abrirLista('Sem data de entrega', semData),
                  cor: AppColors.statusAtencao,
                ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.neutralLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                segmento('Semanal', !mensal,
                    () => formato(CalendarFormat.week)),
                segmento('Mensal', mensal,
                    () => formato(CalendarFormat.month)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime getCurrentDay() {
    if (widget.utils.pedido != null) {
      if (widget.utils.pedido!.deliveryAt != null) {
        return widget.utils.pedido!.deliveryAt!;
      }
    }
    if (widget.utils.day != null) {
      return widget.utils.day!.keys.first;
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            _barraCalendario(),
            Expanded(
              child: Container(
          color: Colors.white.withValues(alpha: 0.5),
          width: double.maxFinite,
          height: double.maxFinite,
          child: Stack(
            children: [
              RawScrollbar(
                controller: _scrollController,
                trackColor: Colors.grey[700],
                thumbColor: Colors.grey[400],
                interactive: true,
                radius: const Radius.circular(4),
                thickness: 8,
                trackVisibility: true,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: TableCalendar(
                    locale: 'pt_BR',
                    availableGestures: AvailableGestures.horizontalSwipe,
                    firstDay: getBorderDates(first: true),
                    lastDay: getBorderDates(last: true),
                    focusedDay: kanbanCtrl.utils.focusedDay,
                    onPageChanged: (focusedDay) {
                      kanbanCtrl.utils.focusedDay = focusedDay;
                    },
                    rowHeight:
                        widget.utils.calendarFormat == CalendarFormat.month
                            ? 170
                            : MediaQuery.of(context).size.height * 1.4,
                    daysOfWeekHeight: 30,
                    calendarFormat: widget.utils.calendarFormat,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      // "Outubro de 2026"
                      titleTextFormatter: (date, locale) {
                        final t = DateFormat.yMMMM('pt_BR').format(date);
                        return t[0].toUpperCase() + t.substring(1);
                      },
                      decoration: BoxDecoration(color: Colors.white60),
                      titleTextStyle: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      leftChevronIcon: Icon(Icons.chevron_left),
                      rightChevronIcon: Icon(Icons.chevron_right),
                    ),
                    calendarBuilders: CalendarBuilders(
                      dowBuilder: (context, day) =>
                          KanbanCalendarWeekdayWidget(day),
                      defaultBuilder: (context, day, focusedDay) =>
                          KanbanCalendarBuilderWidget(
                        utils: widget.utils,
                        day: day,
                        pedidos: getPedidos(day),
                        backgroundColor: [6, 7].contains(day.weekday)
                            ? AppColors.neutralLightest
                            : Colors.white,
                        calendarFormat: widget.utils.calendarFormat,
                      ),
                      todayBuilder: (context, day, focusedDay) =>
                          KanbanCalendarBuilderWidget(
                        utils: widget.utils,
                        day: day,
                        pedidos: getPedidos(day),
                        backgroundColor: AppColors.brandSoft,
                        hoje: true,
                        calendarFormat: widget.utils.calendarFormat,
                      ),
                      outsideBuilder: (context, day, focusedDay) =>
                          widget.utils.calendarFormat == CalendarFormat.month
                              ? Container(
                                  width: double.maxFinite,
                                  height: double.maxFinite,
                                  color: Colors.grey.withValues(alpha: 0.9),
                                )
                              : KanbanCalendarBuilderWidget(
                                  utils: widget.utils,
                                  day: day,
                                  pedidos: getPedidos(day),
                                  backgroundColor: [6, 7].contains(day.weekday)
                                      ? AppColors.neutralLightest
                                      : Colors.white,
                                  calendarFormat: widget.utils.calendarFormat,
                                ),
                      disabledBuilder: (context, day, focusedDay) =>
                          KanbanCalendarBuilderWidget(
                        utils: widget.utils,
                        day: day,
                        pedidos: getPedidos(day),
                        backgroundColor: AppColors.neutralLightest,
                        calendarFormat: widget.utils.calendarFormat,
                      ),
                      weekNumberBuilder: (context, weekNumber) =>
                          const SizedBox(),
                    ),
                  ),
                ),
              ),
            ],
          ),
              ),
            ),
          ],
        );
      },
    );
  }
}
