import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/enums/materia_prima_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/archive/archive_model.dart';
import 'package:aco_plus/app/core/components/archive/archive_type.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/materia_prima/materia_prima_controller.dart';
import 'package:aco_plus/app/modules/materia_prima/materia_prima_view_model.dart';
import 'package:aco_plus/app/modules/materia_prima/ui/materias_primas_create_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class MateriasPrimasPage extends StatefulWidget {
  const MateriasPrimasPage({super.key});

  @override
  State<MateriasPrimasPage> createState() => _MateriasPrimasPageState();
}

/// Matérias-primas de uma mesma bitola (a lista é agrupada por bitola)
class _GrupoBitola {
  final BitolaModel bitola;
  final List<MateriaPrimaModel> itens = [];
  _GrupoBitola(this.bitola);
}

class _MateriasPrimasPageState extends State<MateriasPrimasPage> {
  // Filtro "Sem foto" (só escritório)
  bool _soSemFoto = false;

  @override
  void initState() {
    setWebTitle('Matérias Primas');
    FirestoreClient.materiaPrimas.fetch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      baseCtrl.appBarActionsStream.add(<Widget>[
        IconButton(
          onPressed: () => push(context, const MateriaPrimaCreatePage()),
          icon: const Icon(Icons.add, color: Colors.white),
        ),
      ]);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<MateriaPrimaModel>>(
      stream: FirestoreClient.materiaPrimas.dataStream.listen,
      builder: (_, todas) => StreamOut<MateriaPrimaUtils>(
        stream: materiaPrimaCtrl.utilsStream.listen,
        builder: (_, utils) {
          final buscadas = materiaPrimaCtrl
              .getMateriaPrimaesFiltered(utils.search.text, todas)
              .toList();
          var lista = usuario.isOperador
              ? buscadas
                  .where((e) => e.status == MateriaPrimaStatus.disponivel)
                  .toList()
              : buscadas
                  .where((e) =>
                      utils.status.isEmpty || utils.status.contains(e.status))
                  .toList();
          final semFoto = lista.where((e) => _foto(e) == null).length;
          if (usuario.isNotOperador && _soSemFoto) {
            lista = lista.where((e) => _foto(e) == null).toList();
          }
          final grupos = _agruparPorBitola(lista);

          return Container(
            color: AppColors.neutralLightest,
            child: Column(
              children: [
                if (usuario.isNotOperador)
                  _filtros(utils, buscadas, semFoto),
                Expanded(
                  child: lista.isEmpty
                      ? const EmptyData()
                      : RefreshIndicator(
                          onRefresh: () async =>
                              FirestoreClient.materiaPrimas.fetch(),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Operador: uma coluna, como sempre foi.
                              // Escritório: grade em tela larga.
                              final util = constraints.maxWidth - 32;
                              final colunas = usuario.isOperador
                                  ? 1
                                  : util >= 1100
                                      ? 3
                                      : util >= 700
                                          ? 2
                                          : 1;
                              const gap = 8.0;
                              final largura =
                                  (util - gap * (colunas - 1)) / colunas;
                              // Em grade, a bitola já é o título do cartão:
                              // uma grade contínua (na ordem das bitolas)
                              // evita linhas com um cartão só
                              if (colunas > 1) {
                                return ListView(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                  children: [
                                    Wrap(
                                      spacing: gap,
                                      runSpacing: gap,
                                      children: [
                                        for (final grupo in grupos)
                                          for (final mp in grupo.itens)
                                            SizedBox(
                                              width: largura,
                                              child: _cartao(mp),
                                            ),
                                      ],
                                    ),
                                  ],
                                );
                              }
                              return ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 32),
                                children: [
                                  for (final grupo in grupos) ...[
                                    _cabecalhoGrupo(grupo),
                                    for (final mp in grupo.itens)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: gap),
                                        child: _cartao(mp),
                                      ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Busca e filtros (escritório) ─────────────────────────────────────────
  Widget _filtros(
    MateriaPrimaUtils utils,
    List<MateriaPrimaModel> buscadas,
    int semFoto,
  ) {
    int qtd(MateriaPrimaStatus s) => buscadas.where((e) => e.status == s).length;

    void alternar(MateriaPrimaStatus s) {
      if (!utils.status.remove(s)) utils.status.add(s);
      materiaPrimaCtrl.utilsStream.update();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppField(
            hint: 'Buscar bitola, fabricante ou corrida',
            controller: utils.search,
            suffixIcon: Icons.search,
            onChanged: (_) => materiaPrimaCtrl.utilsStream.update(),
          ),
          const H(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chipFiltro(
                'Disponíveis',
                qtd(MateriaPrimaStatus.disponivel),
                ativo: utils.status.contains(MateriaPrimaStatus.disponivel),
                onTap: () => alternar(MateriaPrimaStatus.disponivel),
              ),
              _chipFiltro(
                'Finalizadas',
                qtd(MateriaPrimaStatus.finalizada),
                ativo: utils.status.contains(MateriaPrimaStatus.finalizada),
                onTap: () => alternar(MateriaPrimaStatus.finalizada),
              ),
              _chipFiltro(
                'Sem foto',
                semFoto,
                ativo: _soSemFoto,
                onTap: () => setState(() => _soSemFoto = !_soSemFoto),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipFiltro(
    String label,
    int qtd, {
    required bool ativo,
    required VoidCallback onTap,
  }) {
    final cor = ativo ? Colors.white : AppColors.neutralDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? AppColors.primaryMain : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: ativo ? AppColors.primaryMain : AppColors.neutralLight),
        ),
        child: Text(
          '$label  $qtd',
          style: AppCss.minimumBold.setSize(12.5).setColor(cor),
        ),
      ),
    );
  }

  // ── Agrupamento por bitola (5.0, 6.3, 8.0...) ────────────────────────────
  List<_GrupoBitola> _agruparPorBitola(List<MateriaPrimaModel> lista) {
    final grupos = <String, _GrupoBitola>{};
    for (final mp in lista) {
      grupos.putIfAbsent(mp.produto.id, () => _GrupoBitola(mp.produto))
          .itens
          .add(mp);
    }
    return grupos.values.toList()
      ..sort((a, b) {
        final cmp = a.bitola.sortIndex.compareTo(b.bitola.sortIndex);
        if (cmp != 0) return cmp;
        return a.bitola.number.compareTo(b.bitola.number);
      });
  }

  Widget _cabecalhoGrupo(_GrupoBitola grupo) {
    final n = grupo.itens.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text(
        n > 1
            ? '${grupo.bitola.nome.trim()} · $n ${usuario.isOperador ? 'disponíveis' : 'itens'}'
            : grupo.bitola.nome.trim(),
        style: AppCss.minimumBold
            .setSize(12)
            .setColor(AppColors.neutralMedium)
            .copyWith(letterSpacing: 0.6),
      ),
    );
  }

  // ── Cartão da matéria-prima ──────────────────────────────────────────────
  Widget _cartao(MateriaPrimaModel mp) {
    final disponivel = mp.status == MateriaPrimaStatus.disponivel;
    final forma = _forma(mp.produto);
    final emUso = disponivel ? _ordensEmUso(mp) : 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: usuario.isNotOperador
            ? () => push(MateriaPrimaCreatePage(materiaPrima: mp))
            : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.neutralLight),
          ),
          child: Row(
            children: [
              _miniatura(mp),
              const W(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(mp.produto.nome.trim(),
                            style: AppCss.largeBold.setSize(16)),
                        if (forma != null)
                          Text(forma,
                              style: AppCss.minimumBold
                                  .setSize(12)
                                  .setColor(AppColors.neutralMedium)),
                        _chipStatus(mp.status),
                      ],
                    ),
                    const H(4),
                    Wrap(
                      spacing: 14,
                      runSpacing: 2,
                      children: [
                        _par('Fabricante', mp.fabricanteModel.nome),
                        _par('Corrida', mp.corridaLote),
                      ],
                    ),
                    if (disponivel) ...[
                      const H(4),
                      Row(
                        children: [
                          Icon(Symbols.assignment,
                              size: 14, color: AppColors.neutralMedium),
                          const W(4),
                          Text(
                            emUso == 0
                                ? 'sem ordem aberta'
                                : emUso == 1
                                    ? 'em uso em 1 ordem'
                                    : 'em uso em $emUso ordens',
                            style: AppCss.minimumRegular
                                .setSize(12)
                                .setColor(AppColors.neutralMedium),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const W(12),
              usuario.isOperador
                  ? _botaoFinalizar(mp)
                  : Icon(Icons.chevron_right,
                      size: 20, color: AppColors.neutralMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _par(String rotulo, String valor) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$rotulo ',
            style: AppCss.minimumRegular
                .setSize(12.5)
                .setColor(AppColors.neutralMedium),
          ),
          TextSpan(
            text: valor.trim().isEmpty ? '—' : valor.trim(),
            style: AppCss.minimumRegular
                .setSize(12.5)
                .setColor(AppColors.neutralDark),
          ),
        ],
      ),
    );
  }

  Widget _chipStatus(MateriaPrimaStatus status) {
    final disponivel = status == MateriaPrimaStatus.disponivel;
    final cor = disponivel ? AppColors.statusPronto : AppColors.neutralMedium;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: disponivel
            ? AppColors.statusPronto.withValues(alpha: 0.1)
            : AppColors.neutralLightest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const W(5),
          Text(status.label,
              style: AppCss.minimumBold.setSize(11).setColor(cor)),
        ],
      ),
    );
  }

  /// Mesmo lugar e mesma confirmação de antes; só o visual mudou
  Widget _botaoFinalizar(MateriaPrimaModel mp) {
    return SizedBox(
      width: 170,
      height: 44,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.black,
          backgroundColor: Colors.white,
          side: BorderSide(color: AppColors.neutralLight),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: AppCss.minimumBold.setSize(13),
        ),
        onPressed: () => materiaPrimaCtrl.finalizarMateriaPrima(mp),
        icon: const Icon(Icons.check_circle_outline,
            size: 18, color: AppColors.statusPronto),
        label: const Text('Finalizar'),
      ),
    );
  }

  // ── Foto da etiqueta ─────────────────────────────────────────────────────
  ArchiveModel? _foto(MateriaPrimaModel mp) => mp.anexos.firstWhereOrNull(
        (a) =>
            a.url != null &&
            (a.type == ArchiveType.image || a.mime.startsWith('image/')),
      );

  Widget _miniatura(MateriaPrimaModel mp) {
    final foto = _foto(mp);
    final caixa = BoxDecoration(
      color: AppColors.neutralLightest,
      borderRadius: BorderRadius.circular(8),
    );
    if (foto == null) {
      return Tooltip(
        message: 'Sem foto da etiqueta',
        child: Container(
          width: 52,
          height: 52,
          decoration: caixa,
          child: Icon(Symbols.no_photography,
              size: 22, color: AppColors.neutralMedium),
        ),
      );
    }
    return InkWell(
      onTap: () => _verFoto(foto),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 52,
        decoration: caixa,
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: foto.url!,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Icon(Symbols.broken_image,
              size: 22, color: AppColors.neutralMedium),
        ),
      ),
    );
  }

  void _verFoto(ArchiveModel foto) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: foto.url!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5)),
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Auxiliares ───────────────────────────────────────────────────────────
  /// "rolo" ou "reto", tirado da descrição da bitola
  String? _forma(BitolaModel bitola) {
    final d = bitola.descricao.toUpperCase();
    if (d.contains('ROLO')) return 'rolo';
    if (d.contains('RETO')) return 'reto';
    return null;
  }

  /// Ordens abertas (não arquivadas e ainda não prontas) usando esta MP
  int _ordensEmUso(MateriaPrimaModel mp) => FirestoreClient
      .ordens.ordensNaoArquivadas
      .where((o) =>
          o.materiaPrima?.id == mp.id && o.status != PedidoBitolaStatus.pronto)
      .length;
}
