import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/modulo_importacao/ui/spe/spe_config_page.dart';
import 'package:aco_plus/app/modules/modulo_importacao/ui/tqs/tqs_config_page.dart';
import 'package:flutter/material.dart';

class ModulosImportacaoPage extends StatefulWidget {
  const ModulosImportacaoPage({super.key});

  @override
  State<ModulosImportacaoPage> createState() => _ModulosImportacaoPageState();
}

class _ModulosImportacaoPageState extends State<ModulosImportacaoPage> {
  @override
  void initState() {
    super.initState();
    setWebTitle('AçoPlus - Planejamento e controle de Produção');
  }

  // Lista de módulos disponíveis.
  // Adicione novos módulos aqui conforme forem criados.
  final List<_ModuloInfo> _modulos = [
    _ModuloInfo(
      id: 'spe',
      nome: 'SPE',
      descricao: 'Importa elementos com pesos e bitolas do pedido técnico SPE. Permite compor um pedido PCP a partir de múltiplos pedidos técnicos.',
      icone: Icons.cloud_download_rounded,
      cor: const Color(0xFF3B82F6),
      is_habilitado: true,
    ),
    _ModuloInfo(
      id: 'tqs',
      nome: 'TQS',
      descricao: 'Importa elementos exportados pelo relatório TQS Planilhar via CSV. Não importa pesos totais por bitola.',
      icone: Icons.table_chart_rounded,
      cor: const Color(0xFF10B981),
      is_habilitado: true,
    ),
  ];

  void _onModuloTap(_ModuloInfo modulo) {
    switch (modulo.id) {
      case 'spe':
        push(context, const SpeConfigPage());
        break;
      case 'tqs':
        push(context, const TqsConfigPage());
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          'Módulos de Importação',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        backgroundColor: AppColors.primaryMain,
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      backgroundColor: AppColors.neutralLightest,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho explicativo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryMain.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: AppColors.primaryMain,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Integrações com sistemas externos',
                          style: AppCss.minimumBold.setColor(AppColors.black),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Configure módulos para importar pedidos automaticamente de plataformas e ERPs que seus clientes já utilizam.',
                          style: AppCss.minimumRegular
                              .setColor(AppColors.neutralMedium)
                              .setSize(13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Grid de cartões (3 colunas × 3 linhas)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const colunas = 3;
                  const linhas = 3;
                  const espacamento = 16.0;

                  final larguraCartao =
                      (constraints.maxWidth - espacamento * (colunas - 1)) /
                          colunas;
                  final alturaCartao =
                      (constraints.maxHeight - espacamento * (linhas - 1)) /
                          linhas;
                  final aspectRatio = larguraCartao / alturaCartao;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: colunas,
                      crossAxisSpacing: espacamento,
                      mainAxisSpacing: espacamento,
                      childAspectRatio: aspectRatio,
                    ),
                    itemCount: _modulos.length,
                    itemBuilder: (context, index) {
                      return _ModuloCartao(
                        modulo: _modulos[index],
                        onTap: () => _onModuloTap(_modulos[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Modelo de dados de cada módulo ────────────────────────────────────────────
class _ModuloInfo {
  final String id;
  final String nome;
  final String descricao;
  final IconData icone;
  final Color cor;
  final bool is_habilitado;

  const _ModuloInfo({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.icone,
    required this.cor,
    required this.is_habilitado,
  });
}

// ─── Widget do cartão de módulo ────────────────────────────────────────────────
class _ModuloCartao extends StatefulWidget {
  final _ModuloInfo modulo;
  final VoidCallback onTap;

  const _ModuloCartao({
    required this.modulo,
    required this.onTap,
  });

  @override
  State<_ModuloCartao> createState() => _ModuloCartaoState();
}

class _ModuloCartaoState extends State<_ModuloCartao> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cor = widget.modulo.cor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: _hover
              ? (Matrix4.identity()..translate(0.0, -2.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover ? cor.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
              width: _hover ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _hover
                    ? cor.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _hover ? 16 : 6,
                offset: Offset(0, _hover ? 6 : 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone + badge de status
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.modulo.icone,
                      size: 22,
                      color: cor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.modulo.is_habilitado
                          ? const Color(0xFF10B981).withValues(alpha: 0.10)
                          : Colors.grey.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.modulo.is_habilitado
                          ? 'Disponível'
                          : 'Em breve',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.modulo.is_habilitado
                            ? const Color(0xFF10B981)
                            : Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Nome do módulo
              Text(
                widget.modulo.nome,
                style: AppCss.smallBold.setColor(AppColors.black),
              ),
              const SizedBox(height: 4),

              // Descrição
              Text(
                widget.modulo.descricao,
                style: AppCss.minimumRegular
                    .setColor(AppColors.neutralMedium)
                    .setSize(12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
