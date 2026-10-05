import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/enums/materia_prima_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/models/materia_prima_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_barcode_scanner_page.dart';
import 'package:aco_plus/app/core/components/app_drop_down.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/archive/ui/archive_simple_widget.dart';
import 'package:aco_plus/app/core/components/archive/ui/archives_widget.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/materia_prima/materia_prima_controller.dart';
import 'package:aco_plus/app/modules/materia_prima/materia_prima_view_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class MateriaPrimaCreatePage extends StatefulWidget {
  final MateriaPrimaModel? materiaPrima;
  const MateriaPrimaCreatePage({this.materiaPrima, super.key});

  @override
  State<MateriaPrimaCreatePage> createState() => _MateriaPrimaCreatePageState();
}

class _MateriaPrimaCreatePageState extends State<MateriaPrimaCreatePage> {
  bool _salvando = false;
  String _initialSnapshot = '';

  String _snapshot() {
    final f = materiaPrimaCtrl.form;
    return '${f.fabricanteModel?.id}|${f.produtoModel?.id}|'
        '${f.corridaLote.text}|${f.status}|${f.anexos.length}';
  }

  @override
  void initState() {
    setWebTitle('Nova Matéria Prima');
    materiaPrimaCtrl.init(widget.materiaPrima);
    _initialSnapshot = _snapshot();
    super.initState();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await materiaPrimaCtrl.onConfirm(context, widget.materiaPrima);
    } catch (_) {}
    if (mounted) setState(() => _salvando = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            // Sem mudança (novo ou edição), sai direto
            if (_snapshot() == _initialSnapshot) {
              pop(context);
              return;
            }
            if (await showConfirmDialog(
              'Deseja realmente sair?',
              widget.materiaPrima != null
                  ? 'A edição que realizou será perdida'
                  : 'Os dados da Matéria Prima serão perdidos.',
            ) && context.mounted) {
              pop(context);
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          '${materiaPrimaCtrl.form.isEdit ? 'Editar' : 'Nova'} matéria-prima',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          // Salvar com nome, em destaque
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primaryMain,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                textStyle: AppCss.minimumBold.setSize(13),
              ),
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('Salvar'),
            ),
          ),
          // Excluir longe de um toque acidental
          if (materiaPrimaCtrl.form.isEdit)
            PopupMenuButton<String>(
              tooltip: 'Mais ações',
              icon: Icon(Icons.more_vert, color: AppColors.white),
              onSelected: (_) =>
                  materiaPrimaCtrl.onDelete(context, widget.materiaPrima!),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'excluir',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Text('Excluir matéria-prima',
                        style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
            )
          else
            const W(8),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: materiaPrimaCtrl.formStream.listen,
        builder: (_, form) => body(form),
      ),
    );
  }

  Widget body(MateriaPrimaCreateModel form) {
    return Container(
      color: AppColors.neutralLightest,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _secao(
                    icon: Symbols.badge,
                    titulo: 'Identificação',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final fabricante = _campoFabricante(form);
                        final bitola = _campoBitola(form);
                        if (constraints.maxWidth < 520) {
                          return Column(
                            children: [fabricante, const H(12), bitola],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: fabricante),
                            const W(12),
                            Expanded(child: bitola),
                          ],
                        );
                      },
                    ),
                  ),
                  _secao(
                    icon: Symbols.tag,
                    titulo: 'Corrida / lote',
                    child: Row(
                      children: [
                        Expanded(
                          child: AppField(
                            hint: 'Número da corrida ou lote',
                            controller: form.corridaLote,
                            onChanged: (_) =>
                                materiaPrimaCtrl.formStream.update(),
                          ),
                        ),
                        const W(8),
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.black,
                              side: BorderSide(color: AppColors.neutralLight),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              final result =
                                  await push(AppBarcodeScannerPage());
                              if (result != null) {
                                form.corridaLote.text = result;
                                materiaPrimaCtrl.formStream.update();
                              }
                            },
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: const Text('Ler código'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _secao(
                    icon: Symbols.toggle_on,
                    titulo: 'Status',
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _status(form),
                    ),
                  ),
                  _secao(
                    icon: Symbols.photo_camera,
                    titulo: usuario.isOperador ? 'Foto da etiqueta' : 'Anexos',
                    child: usuario.isOperador
                        ? ArchiveSimpleWidget(
                            mostrarTitulo: false,
                            path: 'materia_primas/${form.id}',
                            archive: form.anexos.firstOrNull,
                            onChanged: (archive) {
                              form.anexos = [archive!];
                              materiaPrimaCtrl.formStream.update();
                            },
                          )
                        : ArchivesWidget(
                            mostrarTitulo: false,
                            path: 'materia_primas/${form.id}',
                            archives: form.anexos,
                            onChanged: (_) =>
                                materiaPrimaCtrl.formStream.update(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoFabricante(MateriaPrimaCreateModel form) {
    return AppDropDown<FabricanteModel?>(
      label: 'Fabricante',
      item: form.fabricanteModel,
      itens: FirestoreClient.fabricantes.data,
      itemLabel: (item) => item!.nome,
      onSelect: (item) {
        form.fabricanteModel = item;
        materiaPrimaCtrl.formStream.update();
      },
    );
  }

  Widget _campoBitola(MateriaPrimaCreateModel form) {
    final produtos = widget.materiaPrima != null
        ? [widget.materiaPrima!.produto]
        : materiaPrimaCtrl.getProdutosAvailable(form.fabricanteModel);
    return AppDropDown<BitolaModel?>(
      label: 'Bitola',
      item: widget.materiaPrima != null
          ? produtos.first
          : produtos.firstWhereOrNull(
              (e) => e.id == form.produtoModel?.id,
            ),
      disable: form.fabricanteModel == null || widget.materiaPrima != null,
      itens: produtos,
      itemLabel: (item) => item!.labelMinified,
      onSelect: (item) {
        form.produtoModel = item;
        materiaPrimaCtrl.formStream.update();
      },
    );
  }

  /// Disponível / Finalizada com um toque (travado para o operador)
  Widget _status(MateriaPrimaCreateModel form) {
    final travado = usuario.isOperador;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutralLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final status in MateriaPrimaStatus.values)
            InkWell(
              onTap: travado || form.status == status
                  ? null
                  : () {
                      form.status = status;
                      materiaPrimaCtrl.formStream.update();
                    },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                color: form.status == status
                    ? (status == MateriaPrimaStatus.disponivel
                        ? AppColors.statusPronto.withValues(alpha: 0.1)
                        : AppColors.neutralLightest)
                    : Colors.white,
                child: Text(
                  status.label,
                  style: AppCss.minimumBold.setSize(13).setColor(
                        form.status == status
                            ? (status == MateriaPrimaStatus.disponivel
                                ? AppColors.statusPronto
                                : AppColors.black)
                            : travado
                                ? AppColors.neutralLight
                                : AppColors.neutralDark,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _secao({
    required IconData icon,
    required String titulo,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.neutralLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.neutralLightest)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.neutralMedium),
                const W(8),
                Text(titulo, style: AppCss.minimumBold.setSize(14)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
