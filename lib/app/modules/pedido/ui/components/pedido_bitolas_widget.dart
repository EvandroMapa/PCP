import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materia_prima_bottom.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materias_primas_create_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordem/ordem_page.dart';
import 'package:aco_plus/app/modules/pedido/pedido_controller.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Aba Bitolas do pedido: tabela com bitola, matéria-prima, status, ordem e
/// peso, total no rodapé. Clicar na linha mostra a linha do tempo do status.
class PedidoProdutosWidget extends StatefulWidget {
  final PedidoModel pedido;

  /// Botões no canto do cabeçalho do cartão (ex.: relatório, nova parcial)
  final List<Widget> acoes;
  const PedidoProdutosWidget(this.pedido, {this.acoes = const [], super.key});

  @override
  State<PedidoProdutosWidget> createState() => _PedidoProdutosWidgetState();
}

class _PedidoProdutosWidgetState extends State<PedidoProdutosWidget> {
  final Set<String> _abertas = {};

  PedidoModel get pedido => widget.pedido;
  bool get _aguardandoEntrada => pedido.isAguardandoEntradaProducao();

  @override
  Widget build(BuildContext context) {
    final total = pedido.produtos.fold(0.0, (s, p) => s + p.qtde);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: StreamOut(
        stream: FirestoreClient.ordens.dataStream.listen,
        builder: (_, __) => LayoutBuilder(
          builder: (context, constraints) {
            final largo = constraints.maxWidth >= 720;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cabecalho(),
                if (largo) _linhaTitulos(),
                if (pedido.produtos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhuma bitola neste pedido',
                      textAlign: TextAlign.center,
                      style: AppCss.minimumRegular
                          .setColor(AppColors.neutralMedium),
                    ),
                  ),
                for (final produto in pedido.produtos) ...[
                  largo ? _linhaLarga(produto) : _linhaEstreita(produto),
                  if (_abertas.contains(produto.id)) _historico(produto),
                ],
                _rodape(total),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Cabeçalho do cartão ─────────────────────────────────────────────────
  Widget _cabecalho() {
    final n = pedido.produtos.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.neutralLightest)),
      ),
      child: Row(
        children: [
          Icon(Symbols.stacks, size: 18, color: AppColors.neutralMedium),
          const SizedBox(width: 8),
          Text(n == 1 ? '1 bitola' : '$n bitolas',
              style: AppCss.minimumBold.setSize(14)),
          const SizedBox(width: 12),
          // Selo e botões à direita; em tela estreita quebram de linha
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_aguardandoEntrada)
                  _chip('Aguardando entrada na produção',
                      AppColors.neutralMedium)
                else if (pedido.produtos.isNotEmpty)
                  _chip('${(pedido.getPrcntgPronto() * 100).percent}% pronto',
                      AppColors.statusPronto),
                ...widget.acoes,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaTitulos() {
    Widget t(String s, int flex, {bool fim = false}) => Expanded(
          flex: flex,
          child: Text(
            s.toUpperCase(),
            textAlign: fim ? TextAlign.end : TextAlign.start,
            style: AppCss.minimumBold
                .setSize(11)
                .setColor(AppColors.neutralMedium)
                .copyWith(letterSpacing: 0.6),
          ),
        );
    return Container(
      color: AppColorsSystem.light.primary[50],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          t('Bitola', 3),
          t('Matéria-prima', 5),
          if (!_aguardandoEntrada) t('Status', 3),
          t('Ordem', 2),
          t('Peso', 3, fim: true),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  // ── Linha em tela larga (colunas) ───────────────────────────────────────
  Widget _linhaLarga(PedidoBitolaModel produto) {
    final aberta = _abertas.contains(produto.id);
    return InkWell(
      onTap: _aguardandoEntrada ? null : () => _alternar(produto),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: aberta ? const Color(0xFFFBFCFD) : null,
          border: Border(bottom: BorderSide(color: AppColors.neutralLightest)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(produto.produto.nome,
                  style: AppCss.minimumBold.setSize(13.5)),
            ),
            Expanded(flex: 5, child: _materiaPrima(produto)),
            if (!_aguardandoEntrada)
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _encolhe(_statusChip(produto)),
                ),
              ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _encolhe(_ordemLink(produto)),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                produto.qtde.toKg(),
                textAlign: TextAlign.end,
                style: AppCss.minimumBold.setSize(13.5).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            SizedBox(
              width: 28,
              child: _aguardandoEntrada
                  ? null
                  : Icon(
                      aberta ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: AppColors.neutralMedium,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Linha em tela estreita (empilhada) ──────────────────────────────────
  Widget _linhaEstreita(PedidoBitolaModel produto) {
    final aberta = _abertas.contains(produto.id);
    return InkWell(
      onTap: _aguardandoEntrada ? null : () => _alternar(produto),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.neutralLightest)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(produto.produto.nome,
                    style: AppCss.minimumBold.setSize(14)),
                const SizedBox(width: 8),
                if (!_aguardandoEntrada) _statusChip(produto),
                const Spacer(),
                Text(produto.qtde.toKg(),
                    style: AppCss.minimumBold.setSize(13.5)),
                if (!_aguardandoEntrada)
                  Icon(aberta ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: AppColors.neutralMedium),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _materiaPrima(produto)),
                _ordemLink(produto),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _encolhe(Widget child) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: child,
      );

  void _alternar(PedidoBitolaModel produto) => setState(() {
        if (!_abertas.remove(produto.id)) _abertas.add(produto.id);
      });

  Widget _materiaPrima(PedidoBitolaModel produto) {
    final ordem = pedidoCtrl.getOrdemByProduto(produto, true);
    final materiaPrima = produto.materiaPrima ?? ordem?.materiaPrima;
    if (materiaPrima == null) {
      return Text('—',
          style: AppCss.minimumRegular.setColor(AppColors.neutralMedium));
    }
    return InkWell(
      onTap: () async {
        final navContext = contextGlobal;
        final result = await showMateriaPrimaBottom(materiaPrima);
        if (result != null && navContext.mounted) {
          push(navContext, MateriaPrimaCreatePage(materiaPrima: materiaPrima));
        }
      },
      child: Text(
        '${materiaPrima.fabricanteModel.nome} · ${materiaPrima.corridaLote}',
        overflow: TextOverflow.ellipsis,
        style: AppCss.minimumRegular
            .setSize(12.5)
            .setColor(AppColors.neutralDark)
            .copyWith(decoration: TextDecoration.underline,
                decorationColor: AppColors.neutralLight),
      ),
    );
  }

  Widget _ordemLink(PedidoBitolaModel produto) {
    final ordem = pedidoCtrl.getOrdemByProduto(produto, true);
    if (ordem == null) {
      return Text('—',
          style: AppCss.minimumRegular.setColor(AppColors.neutralMedium));
    }
    return InkWell(
      onTap: () async {
        await push(context, OrdemPage(ordem.id));
        pedidoCtrl.pedidoStream.update();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.neutralLightest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ordem.localizator, style: AppCss.minimumBold.setSize(12)),
            const SizedBox(width: 3),
            Icon(Icons.open_in_new, size: 12, color: AppColors.neutralMedium),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(PedidoBitolaModel produto) {
    final status = produto.status.getStatusView();
    return _chip(status.label, status.color);
  }

  Widget _chip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(texto, style: AppCss.minimumBold.setSize(11.5).setColor(cor)),
        ],
      ),
    );
  }

  // ── Linha do tempo do status (ao abrir a linha) ─────────────────────────
  Widget _historico(PedidoBitolaModel produto) {
    final etapas = produto.statusess.map((e) => e.copyWith()).toList();
    return Container(
      color: const Color(0xFFFBFCFD),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Wrap(
        spacing: 6,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (int i = 0; i < etapas.length; i++) ...[
            _etapa(etapas[i], ultima: i == etapas.length - 1),
            if (i < etapas.length - 1)
              Icon(Icons.chevron_right, size: 18, color: AppColors.primaryLight),
          ],
        ],
      ),
    );
  }

  Widget _etapa(PedidoBitolaStatusModel etapa, {required bool ultima}) {
    final cor = etapa.status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ultima ? cor.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: ultima ? cor.withValues(alpha: 0.4) : AppColors.neutralLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(etapa.status.label,
                  style: AppCss.minimumBold.setSize(12).copyWith(
                      color: ultima ? cor : AppColors.neutralDark)),
            ],
          ),
          const SizedBox(height: 2),
          Text(etapa.createdAt.textHour(),
              style: AppCss.minimumRegular
                  .setSize(11)
                  .setColor(AppColors.neutralMedium)),
        ],
      ),
    );
  }

  Widget _rodape(double total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      color: AppColorsSystem.light.primary[50],
      child: Row(
        children: [
          Text('Total', style: AppCss.minimumBold.setSize(13.5)),
          const Spacer(),
          Text(total.toKg(), style: AppCss.minimumBold.setSize(14.5)),
          const SizedBox(width: 28),
        ],
      ),
    );
  }
}
