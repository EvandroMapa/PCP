import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/double_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/estoque/estoque_controller.dart';
import 'package:aco_plus/app/modules/estoque/estoque_view_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EstoqueMovimentacaoSection extends StatefulWidget {
  const EstoqueMovimentacaoSection({super.key});

  @override
  State<EstoqueMovimentacaoSection> createState() =>
      _EstoqueMovimentacaoSectionState();
}

class _EstoqueMovimentacaoSectionState
    extends State<EstoqueMovimentacaoSection> {
  /// Estado local para feedback visual imediato — não depende do stream
  String? _chipId;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    // Restaura a bitola selecionada ao voltar para a aba
    final ids = estoqueCtrl.movimentacaoFiltro.produtoIds;
    if (ids.isNotEmpty) _chipId = ids.first;
  }
  @override
  Widget build(BuildContext context) {
    return StreamOut<EstoqueMovimentacaoFiltroModel>(
      stream: estoqueCtrl.movimentacaoFiltroStream.listen,
      builder: (_, filtro) => StreamOut(
        stream: BackendClient.estoquesMovimentacao.dataStream.listen,
        builder: (_, __) => Column(
          children: [
            _cabecalho(filtro),
            const Divider(height: 1),
            _filtrosBitolas(filtro),
            const Divider(height: 1),
            _filtrosPeriodo(filtro),
            const Divider(height: 1),
            Expanded(child: _corpo(filtro)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CABEÇALHO
  // ─────────────────────────────────────────────────────────────────────────

  Widget _cabecalho(EstoqueMovimentacaoFiltroModel filtro) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Icon(Icons.swap_vert_outlined,
              size: 18, color: AppColors.primaryMain),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Movimentação de Estoque', style: AppCss.mediumBold),
                Text(
                  'Extrato cronológico por bitola com saldo inicial e final',
                  style: AppCss.minimumRegular
                      .setColor(Colors.grey[500]!)
                      .setSize(11),
                ),
              ],
            ),
          ),
          if (filtro.temFiltro)
            TextButton.icon(
              onPressed: () {
                filtro.limpar();
                setState(() => _chipId = null);
                estoqueCtrl.movimentacaoFiltroStream.update();
              },
              icon: const Icon(Icons.clear, size: 14),
              label: const Text('Limpar filtros',
                  style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTRO DE BITOLAS — chips clicáveis
  // ─────────────────────────────────────────────────────────────────────────

  Widget _filtrosBitolas(EstoqueMovimentacaoFiltroModel filtro) {
    final produtos = BackendClient.bitolas.data
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    return Container(
      color: const Color(0xFFFAFBFC),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten_outlined,
                  size: 14, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text('Selecione a bitola',
                  style: AppCss.minimumBold
                      .setColor(Colors.grey[600]!)
                      .setSize(12)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: produtos.map((p) {
              final selecionado = _chipId == p.id;
              return GestureDetector(
                onTap: () {
                  final novoId = selecionado ? null : p.id;
                  // Frame 1: chip visual imediato (sem computação pesada)
                  setState(() {
                    _chipId = novoId;
                    _carregando = novoId != null;
                  });
                  // Frame 2: atualiza filtro + dispara cálculo do extrato
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    if (novoId != null) {
                      filtro.produtoIds = [novoId];
                    } else {
                      filtro.produtoIds.clear();
                    }
                    estoqueCtrl.movimentacaoFiltroStream.update();
                  });
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) setState(() => _carregando = false);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selecionado
                        ? AppColors.primaryMain.withValues(alpha: 0.10)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selecionado
                          ? AppColors.primaryMain.withValues(alpha: 0.40)
                          : const Color(0xFFE2E8F0),
                      width: selecionado ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selecionado) ...[
                        Icon(Icons.check_rounded,
                            size: 12, color: AppColors.primaryMain),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        p.nome,
                        style: AppCss.minimumBold
                            .setSize(11)
                            .setColor(selecionado
                                ? AppColors.primaryMain
                                : Colors.grey[700]!),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILTRO DE PERÍODO
  // ─────────────────────────────────────────────────────────────────────────

  Widget _filtrosPeriodo(EstoqueMovimentacaoFiltroModel filtro) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(Icons.date_range_outlined, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Text('Período:',
              style: AppCss.minimumBold
                  .setColor(Colors.grey[600]!)
                  .setSize(12)),
          const SizedBox(width: 8),
          _chipData(
            label: filtro.dataInicio.text(),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: filtro.dataInicio,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                filtro.dataInicio = d;
                estoqueCtrl.movimentacaoFiltroStream.update();
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('→',
                style: AppCss.minimumRegular
                    .setColor(Colors.grey[400]!)
                    .setSize(12)),
          ),
          _chipData(
            label: filtro.dataFim != null ? filtro.dataFim!.text() : 'hoje',
            faded: filtro.dataFim == null,
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: filtro.dataFim ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                filtro.dataFim = d;
                estoqueCtrl.movimentacaoFiltroStream.update();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _chipData({
    required String label,
    required VoidCallback onTap,
    bool faded = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: faded
              ? Colors.grey.withValues(alpha: 0.06)
              : AppColors.primaryMain.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: faded
                ? Colors.grey.withValues(alpha: 0.20)
                : AppColors.primaryMain.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 11,
              color: faded ? Colors.grey[400] : AppColors.primaryMain,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppCss.minimumBold
                  .setSize(11)
                  .setColor(faded
                      ? Colors.grey[500]!
                      : AppColors.primaryMain),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CORPO PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────

  Widget _corpo(EstoqueMovimentacaoFiltroModel filtro) {
    // Usa _chipId (estado local) para resposta imediata ao clique
    if (_chipId == null) {
      return _estadoVazio(
        icon: Icons.touch_app_outlined,
        titulo: 'Selecione uma bitola',
        subtitulo: 'Escolha uma bitola acima para visualizar o extrato',
      );
    }

    // filtro.produtoIds pode estar vazio por 1 frame (atualização diferida)
    if (filtro.produtoIds.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Column(
      children: [
        // Barra de carregamento visível enquanto o extrato processa
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _carregando ? 2 : 0,
          child: _carregando
              ? LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: AppColors.primaryMain,
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: _listaMovimentacoes(filtro)),
      ],
    );
  }

  Widget _listaMovimentacoes(EstoqueMovimentacaoFiltroModel filtro) {
    final produtos = BackendClient.bitolas.data
        .where((p) => filtro.produtoIds.contains(p.id))
        .toList()
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: produtos.length,
      itemBuilder: (_, i) => _blocoProduto(produtos[i]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BLOCO POR PRODUTO
  // ─────────────────────────────────────────────────────────────────────────

  Widget _blocoProduto(BitolaModel produto) {
    final (saldoInicial, linhas) =
        estoqueCtrl.getExtratoPorProduto(produto);
    final saldoFinal =
        linhas.isNotEmpty ? linhas.last.saldoAcumulado : saldoInicial;

    final totalEntradas = linhas
        .where((l) => l.isEntrada)
        .fold(0.0, (s, l) => s + l.quantidade.abs());
    final totalSaidas = linhas
        .where((l) => !l.isEntrada)
        .fold(0.0, (s, l) => s + l.quantidade.abs());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [


          // ── KPIs resumo ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                _kpi('Saldo Inicial', saldoInicial.toKg(),
                    Colors.grey[600]!, Icons.history_outlined),
                const SizedBox(width: 6),
                _kpi('Entradas', '+${totalEntradas.toKg()}',
                    Colors.green[600]!, Icons.arrow_upward_rounded),
                const SizedBox(width: 6),
                _kpi('Saídas', '-${totalSaidas.toKg()}',
                    Colors.orange[600]!, Icons.arrow_downward_rounded),
                const SizedBox(width: 6),
                _kpi(
                  'Saldo Final',
                  saldoFinal.toKg(),
                  saldoFinal < 0 ? Colors.red[700]! : Colors.teal[700]!,
                  saldoFinal < 0
                      ? Icons.warning_amber_rounded
                      : Icons.account_balance_outlined,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Linha de saldo inicial ─────────────────────────────────────
          _linhaSaldo(
            label: 'Saldo inicial',
            valor: saldoInicial.toKg(),
            icon: Icons.flag_outlined,
            cor: Colors.grey[500]!,
          ),

          if (linhas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _estadoVazio(
                icon: Icons.inbox_outlined,
                titulo: 'Nenhuma movimentação no período',
                subtitulo: 'Ajuste o intervalo de datas para ampliar a busca',
              ),
            )
          else
            ...linhas.map((l) => _linhaEvento(l)),

          // ── Linha de saldo final ───────────────────────────────────────
          _linhaSaldo(
            label: 'Saldo final',
            valor: saldoFinal.toKg(),
            icon: saldoFinal < 0
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            cor: saldoFinal < 0 ? Colors.red[700]! : Colors.teal[700]!,
            destaque: true,
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // KPI CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _kpi(
      String label, String valor, Color cor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 11, color: cor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: AppCss.minimumRegular
                        .setColor(cor.withValues(alpha: 0.80))
                        .setSize(9)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(valor,
                style: AppCss.minimumBold.setColor(cor).setSize(11)),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LINHA DE SALDO (inicial / final)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _linhaSaldo({
    required String label,
    required String valor,
    required IconData icon,
    required Color cor,
    bool destaque = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: destaque ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: cor),
          const SizedBox(width: 8),
          Text(label,
              style: AppCss.minimumBold
                  .setColor(cor)
                  .setSize(12)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: cor.withValues(alpha: 0.25)),
            ),
            child: Text(valor,
                style: AppCss.minimumBold
                    .setColor(cor)
                    .setSize(12)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LINHA DE EVENTO (movimentação)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _linhaEvento(EstoqueLinhaMovimentacao linha) {
    final isEntrada = linha.isEntrada;
    final cor = isEntrada ? Colors.green[600]! : Colors.orange[600]!;
    final corSaldo = linha.saldoAcumulado < 0
        ? Colors.red[700]!
        : Colors.grey[600]!;
    final qtdeTxt =
        '${isEntrada ? '+' : '-'}${linha.quantidade.abs().toKg()}';
    final hora =
        DateFormat("dd/MM/yyyy 'às' HH:mm").format(linha.dataHora);

    final isBaixa = linha.tipoValue == 'baixa_producao';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Faixa colorida lateral ─────────────────────────────────
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: cor,
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8)),
              ),
            ),
            const SizedBox(width: 10),

            // ── Ícone ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  isEntrada
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 14,
                  color: cor,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ── Conteúdo ───────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Badge de tipo
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(linha.tipoLabel,
                              style: AppCss.minimumBold
                                  .setColor(cor)
                                  .setSize(9)),
                        ),
                        const SizedBox(width: 6),
                        // Quantidade
                        Text(qtdeTxt,
                            style: AppCss.minimumBold
                                .setColor(cor)
                                .setSize(12)),
                        const Spacer(),
                        // Saldo acumulado
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('saldo',
                                style: AppCss.minimumRegular
                                    .setColor(Colors.grey[400]!)
                                    .setSize(9)),
                            Text(linha.saldoAcumulado.toKg(),
                                style: AppCss.minimumBold
                                    .setColor(corSaldo)
                                    .setSize(11)),
                          ],
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Hora
                    Text(hora,
                        style: AppCss.minimumRegular
                            .setColor(Colors.grey[400]!)
                            .setSize(10)),

                    // Referência da ordem (baixa de produção)
                    if (isBaixa && linha.ordemId != null) ...{
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Builder(builder: (context) {
                          // Busca o id da ordem para exibir
                          final ordem = BackendClient.ordens.data
                              .cast<dynamic>()
                              .firstWhere(
                                (o) => o.id == linha.ordemId,
                                orElse: () => null,
                              );
                          final ordemLabel = ordem != null
                              ? 'Ordem: ${ordem.id}'
                              : linha.observacao ?? 'Baixa de produção';
                          return Row(
                            children: [
                              Icon(Icons.precision_manufacturing_outlined,
                                  size: 11, color: Colors.orange[600]),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  ordemLabel,
                                  style: AppCss.minimumBold
                                      .setColor(Colors.orange[700]!)
                                      .setSize(11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    } else if (linha.observacao != null &&
                        linha.observacao!.isNotEmpty) ...{
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          linha.observacao!,
                          style: AppCss.minimumRegular
                              .setColor(Colors.grey[500]!)
                              .setSize(11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    },

                    // Usuário
                    if (linha.usuarioNome != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 10, color: Colors.grey[350]),
                            const SizedBox(width: 3),
                            Text(linha.usuarioNome!,
                                style: AppCss.minimumRegular
                                    .setColor(Colors.grey[400]!)
                                    .setSize(10)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ESTADO VAZIO
  // ─────────────────────────────────────────────────────────────────────────

  Widget _estadoVazio({
    required IconData icon,
    required String titulo,
    required String subtitulo,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(titulo,
              style:
                  AppCss.minimumBold.setColor(Colors.grey[500]!).setSize(13)),
          const SizedBox(height: 4),
          Text(subtitulo,
              style: AppCss.minimumRegular
                  .setColor(Colors.grey[400]!)
                  .setSize(11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
