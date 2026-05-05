import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/done_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/patio/patio_controller.dart';
import 'package:aco_plus/app/modules/patio/patio_view_model.dart';
import 'package:flutter/material.dart';

class PatioCreatePage extends StatefulWidget {
  final PatioModel? patio;
  const PatioCreatePage({this.patio, super.key});

  @override
  State<PatioCreatePage> createState() => _PatioCreatePageState();
}

class _PatioCreatePageState extends State<PatioCreatePage> {
  String _nomeInicial = '';
  String _comprInicial = '';
  String _largInicial = '';

  @override
  void initState() {
    setWebTitle('Novo Pátio');
    patioCtrl.init(widget.patio);
    final f = patioCtrl.form;
    _nomeInicial = f.nome.text;
    _comprInicial = f.comprimento.text;
    _largInicial = f.largura.text;
    super.initState();
  }

  bool get _temAlteracao {
    final f = patioCtrl.form;
    return f.nome.text != _nomeInicial ||
        f.comprimento.text != _comprInicial ||
        f.largura.text != _largInicial;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            if (!_temAlteracao) {
              pop(context);
              return;
            }
            if (await showConfirmDialog(
              'Deseja realmente sair?',
              widget.patio != null
                  ? 'A edição que realizou será perdida'
                  : 'Os dados do Pátio serão perdidos.',
            )) {
              pop(context);
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          '${patioCtrl.form.isEdit ? 'Editar' : 'Adicionar'} Pátio',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          IconLoadingButton(
            () async => await patioCtrl.onConfirm(context, widget.patio),
          ),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: patioCtrl.formStream.listen,
        builder: (_, form) => body(form),
      ),
    );
  }

  Widget body(PatioCreateModel form) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppField(
          label: 'Nome',
          controller: form.nome,
          onChanged: (_) => patioCtrl.formStream.update(),
        ),
        const H(16),
        Builder(builder: (_) {
          final temBoxes = widget.patio != null &&
              FirestoreClient.boxes.data
                  .any((b) => b.patioId == widget.patio!.id);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (temBoxes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Medidas bloqueadas — este pátio possui boxes definidos.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownMedida(
                      label: 'Comprimento',
                      valor: form.larguraInt,
                      enabled: !temBoxes,
                      onChanged: (v) {
                        form.largura.text = v.toString();
                        patioCtrl.formStream.update();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownMedida(
                      label: 'Largura',
                      valor: form.comprimentoInt,
                      enabled: !temBoxes,
                      onChanged: (v) {
                        form.comprimento.text = v.toString();
                        patioCtrl.formStream.update();
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
        const H(24),
        _buildPreviewMapa(form),
        const H(24),
        if (form.isEdit)
          TextButton.icon(
            style: ButtonStyle(
              fixedSize: const WidgetStatePropertyAll(
                Size.fromWidth(double.maxFinite),
              ),
              foregroundColor: WidgetStatePropertyAll(AppColors.error),
              backgroundColor: WidgetStatePropertyAll(AppColors.white),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: AppCss.radius8,
                  side: BorderSide(color: AppColors.error),
                ),
              ),
            ),
            onPressed: () => patioCtrl.onDelete(context, widget.patio!),
            label: const Text('Excluir'),
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    );
  }

  Widget _buildDropdownMedida({
    required String label,
    required int valor,
    required void Function(int) onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label:*',
              style: AppCss.smallBold,
            ),
            const H(4),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[400]!),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: valor > 0 && valor <= 50 ? valor : null,
                  isExpanded: true,
                  hint: Text(
                    'Selecione (metros)',
                    style: AppCss.smallRegular.setColor(AppColors.neutralDark),
                  ),
                  icon: Icon(Icons.arrow_drop_down,
                      color: AppColors.neutralMedium),
                  items: List.generate(50, (i) => i + 1).map((v) {
                    return DropdownMenuItem<int>(
                      value: v,
                      child: Text('$v m', style: AppCss.smallRegular),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewMapa(PatioCreateModel form) {
    final comprimento = form.comprimentoInt;
    final largura = form.larguraInt;

    if (comprimento <= 0 || largura <= 0) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(Icons.grid_view_rounded, size: 48, color: Colors.grey[400]),
            const H(12),
            Text(
              'Selecione as medidas para visualizar o mapa do pátio',
              textAlign: TextAlign.center,
              style: AppCss.smallRegular.setColor(Colors.grey[500]!),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.map_outlined,
                size: 18, color: AppColors.primaryMain),
            const SizedBox(width: 8),
            Text(
              'Mapa do Pátio',
              style: AppCss.mediumBold.setColor(AppColors.primaryMain),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryMain.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${comprimento}m × ${largura}m',
                style: AppCss.minimumBold.setColor(AppColors.primaryMain),
              ),
            ),
          ],
        ),
        const H(12),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth - 16; // padding
            const maxHeight = 380.0;
            // Calcular cellSize pelo menor ratio para caber em ambos os eixos
            final cellByWidth = availableWidth / comprimento;
            final cellByHeight = maxHeight / largura;
            final cellSize = cellByWidth < cellByHeight ? cellByWidth : cellByHeight;
            final gridWidth = cellSize * comprimento;
            final gridHeight = cellSize * largura;

            return Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: gridWidth,
                      height: gridHeight,
                      child: CustomPaint(
                        painter: _PatioGridPainter(
                          colunas: comprimento,
                          linhas: largura,
                          cellSize: cellSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PatioGridPainter extends CustomPainter {
  final int colunas;
  final int linhas;
  final double cellSize;

  _PatioGridPainter({
    required this.colunas,
    required this.linhas,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fundo do grid
    final bgPaint = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, colunas * cellSize, linhas * cellSize),
      bgPaint,
    );

    // Linhas do grid
    final gridPaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Linhas horizontais
    for (int i = 0; i <= linhas; i++) {
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(colunas * cellSize, i * cellSize),
        gridPaint,
      );
    }

    // Linhas verticais
    for (int i = 0; i <= colunas; i++) {
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, linhas * cellSize),
        gridPaint,
      );
    }

    // Destacar borda externa
    final borderPaint = Paint()
      ..color = AppColors.primaryMain
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, colunas * cellSize, linhas * cellSize),
      borderPaint,
    );

    // Labels dos metros
    if (cellSize >= 12) {
      final textStyle = TextStyle(
        color: const Color(0xFF94A3B8),
        fontSize: (cellSize * 0.35).clamp(6, 10),
      );

      final intervalo = cellSize >= 20 ? 1 : (cellSize >= 14 ? 5 : 10);

      for (int i = 0; i < colunas; i++) {
        if (i % intervalo == 0) {
          final tp = TextPainter(
            text: TextSpan(text: '${i + 1}', style: textStyle),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(
            canvas,
            Offset(
              i * cellSize + (cellSize - tp.width) / 2,
              linhas * cellSize + 2,
            ),
          );
        }
      }

      for (int i = 0; i < linhas; i++) {
        if (i % intervalo == 0) {
          final tp = TextPainter(
            text: TextSpan(text: '${i + 1}', style: textStyle),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(
            canvas,
            Offset(
              colunas * cellSize + 2,
              i * cellSize + (cellSize - tp.height) / 2,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PatioGridPainter oldDelegate) {
    return oldDelegate.colunas != colunas ||
        oldDelegate.linhas != linhas ||
        oldDelegate.cellSize != cellSize;
  }
}
