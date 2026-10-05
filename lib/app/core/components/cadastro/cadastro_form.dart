import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

// Moldura comum dos formulários de cadastro (bitola, equipamento,
// fabricante...): barra com o nome e um selo, "Salvar" escrito, "Excluir"
// no menu ⋮ e as seções em cartões com largura máxima.

class CadastroFormPage extends StatefulWidget {
  final String titulo;
  final String? selo;

  /// Volta (cada tela decide se pergunta antes de sair)
  final VoidCallback onVoltar;

  /// Null esconde o botão Salvar (sem permissão)
  final Future<void> Function()? onSalvar;

  /// Null esconde o menu ⋮ (cadastro novo ou sem permissão)
  final VoidCallback? onExcluir;
  final String rotuloExcluir;

  final List<Widget> secoes;

  const CadastroFormPage({
    required this.titulo,
    required this.onVoltar,
    required this.secoes,
    this.selo,
    this.onSalvar,
    this.onExcluir,
    this.rotuloExcluir = 'Excluir',
    super.key,
  });

  @override
  State<CadastroFormPage> createState() => _CadastroFormPageState();
}

class _CadastroFormPageState extends State<CadastroFormPage> {
  bool _salvando = false;

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await widget.onSalvar!();
    } catch (_) {}
    if (mounted) setState(() => _salvando = false);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      backgroundColor: AppColors.neutralLightest,
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onVoltar,
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(
                widget.titulo,
                overflow: TextOverflow.ellipsis,
                style: AppCss.largeBold.setColor(AppColors.white).setSize(18),
              ),
            ),
            if (widget.selo != null && widget.selo!.trim().isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  widget.selo!.trim(),
                  style:
                      AppCss.minimumBold.setSize(11).setColor(AppColors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (widget.onSalvar != null)
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
          // Excluir longe de um clique acidental
          if (widget.onExcluir != null)
            PopupMenuButton<String>(
              tooltip: 'Mais ações',
              icon: Icon(Icons.more_vert, color: AppColors.white),
              onSelected: (_) => widget.onExcluir!(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'excluir',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Text(widget.rotuloExcluir,
                        style: TextStyle(color: AppColors.error)),
                  ]),
                ),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < widget.secoes.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    widget.secoes[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cartão de seção do formulário: ícone, título, texto de apoio opcional
class CadastroSecao extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String? apoio;
  final Widget child;

  const CadastroSecao({
    required this.icon,
    required this.titulo,
    required this.child,
    this.apoio,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                const SizedBox(width: 8),
                Text(titulo, style: AppCss.minimumBold.setSize(14)),
                if (apoio != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      apoio!,
                      overflow: TextOverflow.ellipsis,
                      style: AppCss.minimumRegular
                          .setSize(12.5)
                          .setColor(AppColors.neutralMedium),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

/// Dois campos lado a lado em tela larga; um embaixo do outro no celular
class CadastroLinhaCampos extends StatelessWidget {
  final List<Widget> campos;
  final List<int>? flex;
  const CadastroLinhaCampos(this.campos, {this.flex, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < campos.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                campos[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < campos.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(flex: flex?[i] ?? 1, child: campos[i]),
            ],
          ],
        );
      },
    );
  }
}
