import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/ordem_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/ordem_history_type_enum.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/models/history/types/ordem_history_type_status_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/enums/sort_type.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/pdf_download_service/pdf_download_service_mobile.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/modules/relatorio/ui/ordem/relatorio_ordem_pdf_ordem_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/ordem/relatorio_ordem_pdf_status_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/pedido/relatorio_pedido_pdf_page.dart';
import 'package:aco_plus/app/modules/relatorio/ui/produtividade/relatorio_produtividade_pdf_page.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_ordem_view_model.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_pedido_view_model.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_producao_view_model.dart';
import 'package:aco_plus/app/modules/relatorio/view_models/relatorio_produtividade_view_model.dart';
import 'package:aco_plus/app/core/utils/logo_helper.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

final relatorioCtrl = PedidoController();

class PedidoController {
  static final PedidoController _instance = PedidoController._();

  PedidoController._();

  factory PedidoController() => _instance;

  ///RELATORIO DE PEDIDO
  final AppStream<RelatorioPedidoViewModel> pedidoViewModelStream =
      AppStream<RelatorioPedidoViewModel>();
  RelatorioPedidoViewModel get pedidoViewModel => pedidoViewModelStream.value;

  void onCreateRelatorioPedido() {
    List<PedidoModel> pedidos = FirestoreClient.pedidos.data
        .map(
          (e) => e.copyWith(
            produtos: e.produtos.map((e) => e.copyWith()).toList(),
          ),
        )
        .toList();

    pedidos = pedidos
        .where(
          (e) =>
              FirestoreClient.steps.data
                  .where((step) => step.id == e.step.id)
                  .firstOrNull
                  ?.considerarConsumoRelatorioPedidos ??
              true,
        )
        .toList();

    for (PedidoModel pedido in pedidos) {
      List<PedidoBitolaModel> produtos =
          pedido.produtos.map((e) => e.copyWith()).toList();
      pedido.produtos.clear();

      for (PedidoBitolaModel produto in produtos) {
        if (pedidoViewModel.status.contains(produto.statusess.last.status)) {
          pedido.produtos.add(produto);
        }
      }
    }

    pedidos = pedidos
        .where(
          (e) =>
              pedidoViewModel.cliente == null ||
              e.cliente.id == pedidoViewModel.cliente?.id,
        )
        .toList();

    //remove produtos dos pedidos que nao estao na lista de produtos do filtro(view model)
    if (pedidoViewModel.produtos.isNotEmpty) {
      for (PedidoModel pedido in pedidos) {
        List<PedidoBitolaModel> produtos =
            pedido.produtos.map((e) => e.copyWith()).toList();
        pedido.produtos.clear();

        for (PedidoBitolaModel produto in produtos) {
          if (pedidoViewModel.produtos
              .map((e) => e.id)
              .contains(produto.produto.id)) {
            pedido.produtos.add(produto);
          }
        }
      }
    }

    onSortPedidos(pedidos);

    final model = RelatorioPedidoModel(
      pedidoViewModel.cliente,
      pedidoViewModel.status,
      pedidos,
      pedidoViewModel.tipo,
      pedidoViewModel.produtos,
    );

    pedidoViewModel.relatorio = model;
    pedidoViewModelStream.update();
  }

  void onSortPedidos(List<PedidoModel> pedidos) {
    bool isAsc = pedidoViewModel.sortOrder == SortOrder.asc;
    switch (pedidoViewModel.sortType) {
      case SortType.localizator:
        pedidos.sort(
          (a, b) => isAsc
              ? a.localizador.compareTo(b.localizador)
              : b.localizador.compareTo(a.localizador),
        );
        break;
      case SortType.client:
        pedidos.sort(
          (a, b) => isAsc
              ? a.cliente.nome.compareTo(b.cliente.nome)
              : b.cliente.nome.compareTo(a.cliente.nome),
        );
        break;
      case SortType.deliveryAt:
        pedidos.sort((a, b) {
          final aDelivery = a.deliveryAt;
          final bDelivery = b.deliveryAt;
          if (aDelivery == null && bDelivery == null) return 0;
          if (aDelivery == null) return 1;
          if (bDelivery == null) return -1;
          return isAsc
              ? aDelivery.compareTo(bDelivery)
              : bDelivery.compareTo(aDelivery);
        });
        break;
      case SortType.qtde:
        pedidos.sort(
          (a, b) => isAsc
              ? a.getQtdeTotal().compareTo(b.getQtdeTotal())
              : b.getQtdeTotal().compareTo(a.getQtdeTotal()),
        );
        break;
      default:
    }
  }

  Future<void> onExportRelatorioPedidoPDF(
    RelatorioPedidoViewModel pedidoViewModel, {
    RelatorioPedidoQuantidade quantidade = RelatorioPedidoQuantidade.todos,
    String? name,
  }) async {
    final pdf = pw.Document();

    final imageBytes = await LogoHelper.logoBytesForPdf();

    if (quantidade == RelatorioPedidoQuantidade.unico) {
      for (var pedido in pedidoViewModel.relatorio!.pedidos) {
        for (var produto in pedido.produtos) {
          if (produto.statusess.last.status == PedidoBitolaStatus.pronto) {
            final ordem = pedidoCtrl.getOrdemByProduto(produto, true);
            produto.materiaPrima = produto.materiaPrima ?? ordem?.materiaPrima;
            if (produto.materiaPrima != null) {
              for (var anexo in produto.materiaPrima!.anexos) {
                final url = anexo.url;
                final response = await Dio().get(
                  url!,
                  options: Options(responseType: ResponseType.bytes),
                );
                anexo.bytes = Uint8List.fromList(response.data);
              }
            }
          }
        }
      }
    }

    pdf.addPage(
      RelatorioPedidoPdfPage(
        pedidoViewModel.relatorio!,
        quantidade: quantidade,
      ).build(imageBytes),
    );

    final String namePart = name?.toFileName() ??
        '${(pedidoViewModel.cliente?.nome ?? 'todos').toLowerCase().replaceAll(' ', '_')}_status_${(pedidoViewModel.status.map((e) => e.name).join('_')).toLowerCase()}';

    await downloadPDF(
      "m2_relatorio_cliente_$namePart${DateTime.now().toFileName()}.pdf",
      '/relatorio/pedido/',
      await pdf.save(),
    );
  }

  double getPedidosTotal() {
    double qtde = 0;
    for (var pedido in pedidoViewModel.relatorio!.pedidos) {
      for (var produto in pedido.produtos) {
        qtde = qtde + produto.qtde;
      }
    }
    return double.parse(qtde.toStringAsFixed(2));
  }

  double getPedidosTotalPorStatus(PedidoBitolaStatus status) {
    double qtde = 0;
    for (var pedido in pedidoViewModel.relatorio!.pedidos) {
      for (var produto in pedido.produtos) {
        if (produto.statusess.last.status == status) {
          qtde = qtde + produto.qtde;
        }
      }
    }
    return double.parse(qtde.toStringAsFixed(2));
  }

  double getPedidosTotalPorBitola(BitolaModel produto) {
    double qtde = 0;
    for (var pedido in pedidoViewModel.relatorio!.pedidos) {
      for (var produto in pedido.produtos
          .where((e) => e.produto.id == produto.id)
          .toList()) {
        qtde = qtde + produto.qtde;
      }
    }
    return double.parse(qtde.toStringAsFixed(2));
  }

  double getPedidosTotalPorBitolaStatus(
    BitolaModel produto,
    PedidoBitolaStatus status,
  ) {
    double qtde = 0;
    for (var pedido in pedidoViewModel.relatorio!.pedidos) {
      for (var produto in pedido.produtos
          .where((e) => e.produto.id == produto.id)
          .toList()) {
        if (produto.statusess.last.status == status) {
          qtde = qtde + produto.qtde;
        }
      }
    }
    return double.parse(qtde.toStringAsFixed(2));
  }

  ///RELATORIO DE ORDEM
  final AppStream<RelatorioOrdemViewModel> ordemViewModelStream =
      AppStream<RelatorioOrdemViewModel>();
  RelatorioOrdemViewModel get ordemViewModel => ordemViewModelStream.value;

  void onCreateRelatorio() {
    if (ordemViewModel.type == RelatorioOrdemType.STATUS) {
      onCreateRelatorioOrdemStatus();
    } else {
      onCreateRelatorioOrdem();
    }
  }

  void onCreateRelatorioOrdemStatus() {
    List<OrdemModel> ordens = FirestoreClient.ordens.data
        .map(
          (o) => o.copyWith(
            produto: o.produto.copyWith(),
            produtos: o.produtos
                .map(
                  (p) => p.copyWith(
                    statusess: p.statusess.map((s) => s.copyWith()).toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();
    for (final ordem in ordens) {
      ordem.produtos = ordem.produtos
          .where(
            (e) =>
                !e.pedido.localizador.contains('NOTFOUND') &&
                _whereProductStatus(e, ordemViewModel.status),
          )
          .toList();
    }

    ordens.removeWhere((e) => e.produtos.isEmpty);
    if (ordemViewModel.dates != null) {
      ordens = ordens
          .where(
            (e) =>
                e.createdAt.isAfter(ordemViewModel.dates!.start) &&
                e.createdAt.isBefore(ordemViewModel.dates!.end),
          )
          .toList();
    }
    final model = RelatorioOrdemModel.status(
      ordemViewModel.status,
      ordens,
      dates: ordemViewModel.dates,
    );

    ordemViewModel.relatorio = model;
    ordemViewModelStream.update();
  }

  void onCreateRelatorioOrdem() {
    final model = RelatorioOrdemModel.ordem(ordemViewModel.ordem!);

    ordemViewModel.relatorio = model;
    ordemViewModelStream.update();
  }

  bool _whereProductStatus(
    PedidoBitolaModel produto,
    List<RelatorioOrdemStatus> status,
  ) {
    final productStatus = produto.statusess.last.status;
    bool isAvailable = false;
    for (var status in status) {
      switch (status) {
        case RelatorioOrdemStatus.AGUARDANDO_PRODUCAO:
          isAvailable = [
            PedidoBitolaStatus.separado,
            PedidoBitolaStatus.aguardandoProducao,
          ].contains(productStatus);
        case RelatorioOrdemStatus.EM_PRODUCAO:
          isAvailable = productStatus == PedidoBitolaStatus.produzindo;
        case RelatorioOrdemStatus.PRODUZIDAS:
          isAvailable = productStatus == PedidoBitolaStatus.pronto;
      }
    }
    return isAvailable;
  }

  double getOrdemTotal() {
    double qtde = 0;
    for (var orden in ordemViewModel.relatorio!.ordens) {
      for (var produto in orden.produtos) {
        qtde = qtde + produto.qtde;
      }
    }
    return double.parse(qtde.toStringAsFixed(2));
  }

  List<BitolaModel> getTiposProdutosId() {
    List<BitolaModel> produtos = [];
    for (var ordem in ordemViewModel.relatorio!.ordens) {
      for (var produto in ordem.produtos) {
        if (produtos.map((e) => e.id).contains(produto.produto.id) == false) {
          if (produto.produto.nome != 'Bitola não encontrada') {
            produtos.add(produto.produto);
          }
        }
      }
    }
    return produtos.toList();
  }

  List<PedidoBitolaModel> getOrdemTotalProduto() {
    List<PedidoBitolaModel> pedidoProdutos = [];
    final types = getTiposProdutosId();
    for (var type in types) {
      double qtde = 0;
      for (var ordem in ordemViewModel.relatorio!.ordens) {
        for (var produto in ordem.produtos) {
          if (produto.produto.id == type.id) {
            qtde = qtde + produto.qtde;
          }
        }
      }
      pedidoProdutos.add(
        PedidoBitolaModel(
          id: 'total',
          produto: type,
          qtde: qtde,
          qtdeOriginal: qtde,
          statusess: [],
          clienteId: '',
          obraId: '',
          pedidoId: '',
        ),
      );
    }
    pedidoProdutos.sort((a, b) => a.produto.number.compareTo(b.produto.number));
    return pedidoProdutos;
  }

  Future<void> onExportRelatorioOrdemPDF(
    RelatorioOrdensPdfExportarTipo tipo,
  ) async {
    final pdf = pw.Document();

    final imageBytes = await LogoHelper.logoBytesForPdf();

    var isOrdemType = ordemViewModel.type == RelatorioOrdemType.ORDEM;

    pdf.addPage(
      (isOrdemType
          ? RelatorioOrdemPdfOrdemPage(
              ordemViewModel.relatorio!,
              tipo,
            ).build(imageBytes)
          : RelatorioOrdemPdfStatusPage(
              ordemViewModel.relatorio!,
              tipo,
            ).build(imageBytes)),
    );

    final name = isOrdemType
        ? "m2_relatorio_ordem_${ordemViewModel.relatorio!.ordem.localizator.toLowerCase()}${DateTime.now().toFileName()}.pdf"
        : "m2_relatorio_bitola_status_${ordemViewModel.status.map((e) => e.label).join('_').toLowerCase()}${DateTime.now().toFileName()}.pdf";

    await downloadPDF(name, '/relatorio/ordem/', await pdf.save());
  }

  Future<void> onExportRelatorioOrdemUniquePDF(
    RelatorioOrdemModel relatorio,
  ) async {
    final pdf = pw.Document();

    final imageBytes = await LogoHelper.logoBytesForPdf();

    pdf.addPage(
      RelatorioOrdemPdfOrdemPage(
        relatorio,
        RelatorioOrdensPdfExportarTipo.completo,
      ).build(imageBytes),
    );

    final name =
        "m2_relatorio_ordem_${ordemViewModel.relatorio!.ordem.localizator.toLowerCase()}_${DateTime.now().toFileName()}.pdf";

    await downloadPDF(name, '/relatorio/ordem/', await pdf.save());
  }

  Future<void> onSearchRelatorio() async {
    try {
      final ordem = FirestoreClient.ordens.data
          .map((e) => e.copyWith())
          .firstWhere(
            (e) =>
                e.id.toCompare.contains(ordemViewModel.ordemEC.text.toCompare),
          );
      ordemViewModel.ordem = ordem;
      ordemViewModelStream.update();
      onCreateRelatorio();
    } catch (e) {
      NotificationService.showNegative(
        'Não foi encontrado ordem com esse filtro',
        'Verifique o filtro informado',
      );
    }
  }

  /// Exporta PDF do novo relatório de ordens produzidas
  Future<void> exportarRelatorioOrdensProduzidas(
    List<OrdemModel> ordens,
    RelatorioOrdensPdfExportarTipo tipo, {
    DateTimeRange? periodo,
    BitolaModel? bitola,
  }) async {
    final pdf = pw.Document();
    final imageBytes = await LogoHelper.logoBytesForPdf();

    // Reutiliza RelatorioOrdemPdfStatusPage com um modelo fake de status
    // contendo as ordens já filtradas externamente
    final modelo = RelatorioOrdemModel.status(
      [],
      ordens,
      dates: periodo,
    );

    pdf.addPage(
      RelatorioOrdemPdfStatusPage(modelo, tipo).build(imageBytes),
    );

    final sufixo = bitola != null ? '_${bitola.descricao}' : '';
    final name =
        'relatorio_ordens_produzidas$sufixo${DateTime.now().toFileName()}.pdf';

    await downloadPDF(name, '/relatorio/ordem/', await pdf.save());
  }

  //RELATORIO DE PRODUÇÃO
  final AppStream<RelatorioProducaoViewModel> producaoViewModelStream =
      AppStream<RelatorioProducaoViewModel>();
  RelatorioProducaoViewModel get producaoViewModel =>
      producaoViewModelStream.value;

  List<PedidoBitolaModel> getOrdemTotalTempoProduto() {
    List<PedidoBitolaModel> pedidoProdutos = [];
    final types = getOrdemTiposProdutosId();
    for (var type in types) {
      double qtde = 0;
      for (var ordem in producaoViewModel.relatorio!.ordens) {
        for (var produto in ordem.produtos) {
          if (produto.produto.id == type.id) {
            qtde = qtde + produto.qtde;
          }
        }
      }
      pedidoProdutos.add(
        PedidoBitolaModel(
          id: 'total',
          produto: type,
          qtde: qtde,
          qtdeOriginal: qtde,
          statusess: [],
          clienteId: '',
          obraId: '',
          pedidoId: '',
        ),
      );
    }
    pedidoProdutos.sort((a, b) => a.produto.number.compareTo(b.produto.number));
    return pedidoProdutos;
  }

  List<BitolaModel> getOrdemTiposProdutosId() {
    List<BitolaModel> produtos = [];
    for (var ordem in producaoViewModel.relatorio!.ordens) {
      for (var produto in ordem.produtos) {
        if (produtos.map((e) => e.id).contains(produto.produto.id) == false) {
          if (produto.produto.nome != 'Bitola não encontrada') {
            produtos.add(produto.produto);
          }
        }
      }
    }
    return produtos.toList();
  }

  void onCreateRelatorioProducao() {
    List<OrdemModel> ordens = FirestoreClient.ordens.data
        .map(
          (o) => o.copyWith(
            produto: o.produto.copyWith(),
            produtos: o.produtos
                .map(
                  (p) => p.copyWith(
                    statusess: p.statusess.map((s) => s.copyWith()).toList(),
                  ),
                )
                .toList(),
          ),
        )
        .toList();

    if (producaoViewModel.produtos.isNotEmpty) {
      ordens = ordens
          .where(
            (e) => producaoViewModel.produtos
                .map((e) => e.id)
                .contains(e.produto.id),
          )
          .toList();
    }

    if (producaoViewModel.localizadorEC.text.isNotEmpty) {
      ordens = ordens
          .where(
            (e) => e.localizator.toCompare.contains(
              producaoViewModel.localizadorEC.text.toCompare,
            ),
          )
          .toList();
    }

    if (producaoViewModel.dates != null) {
      ordens = ordens
          .where(
            (e) =>
                e.createdAt.isAfter(producaoViewModel.dates!.start) &&
                e.createdAt.isBefore(producaoViewModel.dates!.end),
          )
          .toList();
    }

    final List<PedidoProdutoTurno> turnos = [];
    for (final ordem in ordens) {
      for (final produto in ordem.produtos) {
        turnos.addAll(produto.getTurnos(ordem));
      }
    }

    final model = RelatorioProducaoModel(
      ordens: ordens,
      dates: producaoViewModel.dates,
      localizador: producaoViewModel.localizadorEC.text,
      turnos: turnos,
    );

    producaoViewModel.relatorio = model;
    producaoViewModelStream.update();
  }

  Duration getTempoProducao(List<PedidoProdutoTurno> turnos) {
    if (turnos.isEmpty) return Duration.zero;
    if (turnos.length == 1) return turnos.first.duration;
    return turnos.fold(
      Duration.zero,
      (previousValue, element) => previousValue + element.duration,
    );
  }

  // bool _whereProductStatus(
  //   PedidoBitolaModel produto,
  //   List<RelatorioOrdemStatus> status,
  // ) {
  //   final productStatus = produto.statusess.last.status;
  //   bool isAvailable = false;
  //   for (var status in status) {
  //     switch (status) {
  //       case RelatorioOrdemStatus.AGUARDANDO_PRODUCAO:
  //         isAvailable = [
  //           PedidoBitolaStatus.separado,
  //           PedidoBitolaStatus.aguardandoProducao,
  //         ].contains(productStatus);
  //       case RelatorioOrdemStatus.EM_PRODUCAO:
  //         isAvailable = productStatus == PedidoBitolaStatus.produzindo;
  //       case RelatorioOrdemStatus.PRODUZIDAS:
  //         isAvailable = productStatus == PedidoBitolaStatus.pronto;
  //     }
  //   }
  //   return isAvailable;
  // }

  // double getOrdemTotal() {
  //   double qtde = 0;
  //   for (var orden in ordemViewModel.relatorio!.ordens) {
  //     for (var produto in orden.produtos) {
  //       qtde = qtde + produto.qtde;
  //     }
  //   }
  //   return double.parse(qtde.toStringAsFixed(2));
  // }

  // List<BitolaModel> getTiposProdutosId() {
  //   List<BitolaModel> produtos = [];
  //   for (var ordem in ordemViewModel.relatorio!.ordens) {
  //     for (var produto in ordem.produtos) {
  //       if (produtos.map((e) => e.id).contains(produto.produto.id) == false) {
  //         if (produto.produto.nome != 'Bitola não encontrada') {
  //           produtos.add(produto.produto);
  //         }
  //       }
  //     }
  //   }
  //   return produtos.toList();
  // }

  // List<PedidoBitolaModel> getOrdemTotalProduto() {
  //   List<PedidoBitolaModel> pedidoProdutos = [];
  //   final types = getTiposProdutosId();
  //   for (var type in types) {
  //     double qtde = 0;
  //     for (var ordem in ordemViewModel.relatorio!.ordens) {
  //       for (var produto in ordem.produtos) {
  //         if (produto.produto.id == type.id) {
  //           qtde = qtde + produto.qtde;
  //         }
  //       }
  //     }
  //     pedidoProdutos.add(
  //       PedidoBitolaModel(
  //         id: 'total',
  //         produto: type,
  //         qtde: qtde,
  //         statusess: [],
  //         clienteId: '',
  //         obraId: '',
  //         pedidoId: '',
  //       ),
  //     );
  //   }
  //   pedidoProdutos.sort((a, b) => a.produto.number.compareTo(b.produto.number));
  //   return pedidoProdutos;
  // }

  Future<void> onExportRelatorioProducaoPDF(
    RelatorioProducaoModel model,
  ) async {
    // final pdf = pw.Document();

    // final img = await rootBundle.load('assets/images/logo.png');
    // final imageBytes = img.buffer.asUint8List();

    // var isOrdemType = ordemViewModel.type == RelatorioOrdemType.ORDEM;

    // pdf.addPage(
    //   (isOrdemType
    //       ? RelatorioOrdemPdfOrdemPage(
    //           ordemViewModel.relatorio!,
    //           tipo,
    //         ).build(imageBytes)
    //       : RelatorioOrdemPdfStatusPage(
    //           ordemViewModel.relatorio!,
    //           tipo,
    //         ).build(imageBytes)),
    // );

    // final name = isOrdemType
    //     ? "m2_relatorio_ordem_${ordemViewModel.relatorio!.ordem.localizator.toLowerCase()}${DateTime.now().toFileName()}.pdf"
    //     : "m2_relatorio_bitola_status_${ordemViewModel.status.map((e) => e.label).join('_').toLowerCase()}${DateTime.now().toFileName()}.pdf";

    // await downloadPDF(name, '/relatorio/ordem/', await pdf.save());
  }

  Duration getOrdensTempoProducao(List<OrdemModel> ordens) {
    List<Duration> durations = [];
    for (var ordem in ordens) {
      final duration = ordem.durations;
      if (duration != null) {
        durations.add(
          (duration.endedAt ?? DateTime.now()).difference(duration.startedAt),
        );
      }
    }
    if (durations.isEmpty) return Duration.zero;
    if (durations.length == 1) return durations.first;

    return durations.reduce((a, b) => a + b);
  }

  Duration getOrdensTempPorBitola(
    BitolaModel produto,
    List<OrdemModel> ordens,
  ) {
    List<Duration> durations = [];
    for (var ordem in ordens.where((ordem) => ordem.produto.id == produto.id)) {
      final duration = ordem.durations;
      if (duration != null) {
        durations.add(
          (duration.endedAt ?? DateTime.now()).difference(duration.startedAt),
        );
      }
    }
    if (durations.isEmpty) return Duration.zero;
    if (durations.length == 1) return durations.first;

    return durations.reduce((a, b) => a + b);
  }

  // ═══════════════════════════════════════════════════════════════════
  // RELATÓRIO DE PRODUTIVIDADE CD
  // ═══════════════════════════════════════════════════════════════════

  final AppStream<RelatorioProdutividadeViewModel>
      produtividadeViewModelStream =
      AppStream<RelatorioProdutividadeViewModel>();
  RelatorioProdutividadeViewModel get produtividadeViewModel =>
      produtividadeViewModelStream.value;

  Future<void> onCreateRelatorioProdutividade() async {
    final vm = produtividadeViewModel;
    final inicio = vm.periodo.start;
    final fim = vm.periodo.end;

    // Recarrega ordens arquivadas do período selecionado
    await FirestoreClient.ordens.startOnlyArquivadas(de: inicio, ate: fim);

    final bitolaIds = vm.bitolas.map((e) => e.id).toSet();

    final detalhes = <ProdutividadeDetalhe>[];

    // Inclui ordens ativas + arquivadas para cobrir produções já finalizadas
    final todasOrdens = [
      ...FirestoreClient.ordens.data,
      ...FirestoreClient.ordens.ordensArquivadas,
    ];

    for (final ordem in todasOrdens) {
      // Filtra por bitola da ordem
      if (!bitolaIds.contains(ordem.produto.id)) continue;

      // Itera os produtos da ordem (cada produto = 1 pedido/bitola na OS)
      for (final produto in ordem.produtos) {
        // Verifica se o produto tem status "Pronto"
        if (produto.status.status != PedidoBitolaStatus.pronto) continue;

        // Verifica se a bitola do produto está no filtro
        if (!bitolaIds.contains(produto.produto.id)) continue;

        // Busca a data em que ficou "Pronto" (último statusess com pronto)
        final statusPronto = produto.statusess
            .where((s) => s.status == PedidoBitolaStatus.pronto)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

        if (statusPronto.isEmpty) continue;

        final dataPronto = statusPronto.last.createdAt;

        // Verifica se o encerramento está dentro do período
        if (dataPronto.isBefore(inicio) || dataPronto.isAfter(fim)) {
          continue;
        }

        // Filtra por operador: busca no history quem colocou em Pronto
        if (vm.operador != null) {
          final eventoOperador = ordem.history
              .where((e) =>
                  e.type == OrdemHistoryTypeEnum.statusProdutoAlterada)
              .where((e) {
            final d = e.data as OrdemHistoryTypeStatusBitolaModel;
            return d.statusProdutos.status == PedidoBitolaStatus.pronto &&
                d.statusProdutos.produtos.any((p) => p.id == produto.id);
          }).lastOrNull;

          if (eventoOperador == null) continue;
          final d = eventoOperador.data as OrdemHistoryTypeStatusBitolaModel;
          if (d.user.id != vm.operador!.id) continue;
        }

        final kg = produto.qtde;
        final massaFinal = produto.produto.massaFinal;
        final metros = massaFinal > 0 ? kg / massaFinal : 0.0;

        String localizador;
        try {
          localizador = produto.pedido.localizador;
        } catch (_) {
          localizador = produto.pedidoId;
        }

        // Busca operador do history (se disponível)
        UsuarioModel? operadorProd;
        final eventoHist = ordem.history
            .where(
                (e) => e.type == OrdemHistoryTypeEnum.statusProdutoAlterada)
            .where((e) {
          final d = e.data as OrdemHistoryTypeStatusBitolaModel;
          return d.statusProdutos.status == PedidoBitolaStatus.pronto &&
              d.statusProdutos.produtos.any((p) => p.id == produto.id);
        }).lastOrNull;
        if (eventoHist != null) {
          operadorProd =
              (eventoHist.data as OrdemHistoryTypeStatusBitolaModel).user;
        }

        detalhes.add(ProdutividadeDetalhe(
          ordemId: ordem.id,
          pedidoLocalizador: localizador,
          bitola: produto.produto,
          kg: kg,
          metros: metros,
          dataEncerramento: dataPronto,
          operador: operadorProd,
        ));
      }
    }

    // Totalização
    final kgTotal = detalhes.fold(0.0, (s, d) => s + d.kg);
    final metrosTotal = detalhes.fold(0.0, (s, d) => s + d.metros);

    // Agrupamento por bitola
    final mapBitola = <String, List<ProdutividadeDetalhe>>{};
    for (final d in detalhes) {
      mapBitola.putIfAbsent(d.bitola.id, () => []).add(d);
    }
    final porBitola = mapBitola.entries.map((e) {
      final lista = e.value;
      return ProdutividadePorBitola(
        bitola: lista.first.bitola,
        kg: lista.fold(0.0, (s, d) => s + d.kg),
        metros: lista.fold(0.0, (s, d) => s + d.metros),
        quantidade: lista.length,
      );
    }).toList()
      ..sort((a, b) => a.bitola.sortIndex.compareTo(b.bitola.sortIndex));

    // Agrupamento por dia
    final mapDia = <String, List<ProdutividadeDetalhe>>{};
    for (final d in detalhes) {
      final chave =
          '${d.dataEncerramento.year}-${d.dataEncerramento.month.toString().padLeft(2, '0')}-${d.dataEncerramento.day.toString().padLeft(2, '0')}';
      mapDia.putIfAbsent(chave, () => []).add(d);
    }
    final porDia = mapDia.entries.map((e) {
      final lista = e.value;
      return ProdutividadePorDia(
        data: DateTime.parse(e.key),
        kg: lista.fold(0.0, (s, d) => s + d.kg),
        metros: lista.fold(0.0, (s, d) => s + d.metros),
        quantidade: lista.length,
      );
    }).toList()
      ..sort((a, b) => a.data.compareTo(b.data));

    vm.relatorio = RelatorioProdutividadeModel(
      kgTotal: kgTotal,
      metrosTotal: metrosTotal,
      qtdeProducoes: detalhes.length,
      porBitola: porBitola,
      porDia: porDia,
      detalhes: detalhes,
    );
    produtividadeViewModelStream.update();
  }

  Future<void> onExportRelatorioProdutividadePDF() async {
    final vm = produtividadeViewModel;
    if (vm.relatorio == null) return;

    final pdf = pw.Document();
    final imageBytes = await LogoHelper.logoBytesForPdf();

    pdf.addPage(
      RelatorioProdutividadePdfPage(
        relatorio: vm.relatorio!,
        periodo: vm.periodo,
        operador: vm.operador,
      ).build(imageBytes),
    );

    final operadorSufixo = vm.operador != null
        ? '_${vm.operador!.nome.toLowerCase().replaceAll(' ', '_')}'
        : '';
    final name =
        'relatorio_produtividade_cd$operadorSufixo${DateTime.now().toFileName()}.pdf';

    await downloadPDF(name, '/relatorio/produtividade/', await pdf.save());
  }
}
