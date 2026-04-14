import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Configurações Gerais', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.secondary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _sectionHeader('Produção'),
          const SizedBox(height: 16),
          _productionSettings(),
          const SizedBox(height: 32),
          _sectionHeader('Desenhos Técnicos'),
          const SizedBox(height: 16),
          _pdfOptimizationSettings(),
          const SizedBox(height: 32),
          _sectionHeader('Interface'),
          const SizedBox(height: 16),
          _layoutSettings(),
          const SizedBox(height: 32),
          _sectionHeader('Apontamento CD'),
          const SizedBox(height: 16),
          _apontamentoSettings(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: AppCss.mediumBold.setSize(16).setColor(AppColors.secondary),
        ),
      ],
    );
  }

  Widget _productionSettings() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Limite de Produção Simultânea',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Quantidade máxima de elementos que podem ser colocados em produção ao mesmo tempo por pedido.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            StreamOut<int>(
              stream: PreferencesService.maxElementosProducao.listen,
              builder: (context, value) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _numericButton(
                      icon: Icons.remove,
                      onPressed: value > 1 
                          ? () => PreferencesService.maxElementosProducao.add(value - 1)
                          : null,
                    ),
                    const SizedBox(width: 24),
                    Container(
                      width: 100,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        value.toString(),
                        style: AppCss.largeBold.setSize(28).setColor(AppColors.secondary),
                      ),
                    ),
                    const SizedBox(width: 24),
                    _numericButton(
                      icon: Icons.add,
                      onPressed: value < 30 
                          ? () => PreferencesService.maxElementosProducao.add(value + 1)
                          : null,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  Widget _pdfOptimizationSettings() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_as_pdf_outlined, color: Colors.deepOrange),
                const SizedBox(width: 12),
                const Text(
                  'Nível de Otimização de PDF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Controla a resolução das imagens geradas a partir dos desenhos técnicos (PDF → JPG).\n'
              '0 = Máxima resolução (arquivo maior) · 10 = Máxima compressão (arquivo menor)',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            StreamOut<int>(
              stream: PreferencesService.pdfOptimizationLevel.listen,
              builder: (context, level) {
                final scale = PreferencesService.pdfScale;
                final quality = PreferencesService.pdfQuality;
                return Column(
                  children: [
                    Row(
                      children: [
                        Text('0', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green[700])),
                        const SizedBox(width: 4),
                        const Text('HD', style: TextStyle(fontSize: 10)),
                        Expanded(
                          child: Slider(
                            value: level.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: level.toString(),
                            activeColor: level <= 3 ? Colors.green : (level <= 7 ? Colors.orange : Colors.red),
                            onChanged: (value) => PreferencesService.pdfOptimizationLevel.add(value.round()),
                          ),
                        ),
                        const Text('Leve', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 4),
                        Text('10', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[700])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'NÍVEL: $level  ·  ESCALA: ${scale.toStringAsFixed(1)}x  ·  JPEG: $quality%',
                            style: AppCss.smallBold.setColor(Colors.deepOrange[800]!),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _numericButton({required IconData icon, VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: onPressed != null ? AppColors.secondary.withValues(alpha: 0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: onPressed != null ? AppColors.secondary.withValues(alpha: 0.3) : Colors.grey[300]!,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: onPressed != null ? AppColors.secondary : Colors.grey[400]),
        onPressed: onPressed,
        iconSize: 28,
        padding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _layoutSettings() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard_customize_outlined, color: Colors.blue),
                const SizedBox(width: 12),
                const Text(
                  'Largura das Colunas do Kanban',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ajuste a largura padrão das etapas no painel do Kanban.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            StreamOut<double>(
              stream: PreferencesService.kanbanColumnWidth.listen,
              builder: (context, width) {
                return Column(
                  children: [
                    Row(
                      children: [
                        const Text('200px', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: width,
                            min: 200,
                            max: 600,
                            divisions: 40,
                            label: '${width.round()} px',
                            onChanged: (value) => PreferencesService.kanbanColumnWidth.add(value),
                          ),
                        ),
                        const Text('600px', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'TAMANHO: ${width.round()} PX',
                        style: AppCss.smallBold.setColor(Colors.blue[800]!),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _apontamentoSettings() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modo de Apontamento de Produção CD',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Define como o operador controla a produção dos pedidos CD/CDA nas ordens de serviço.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            StreamOut<String>(
              stream: PreferencesService.apontamentoProducaoCD.listen,
              builder: (_, currentValue) {
                return Column(
                  children: [
                    _apontamentoOption(
                      title: 'Por Pedido',
                      subtitle: 'Operador muda status diretamente no card do pedido (atual)',
                      icon: Icons.receipt_long_outlined,
                      value: 'por_pedido',
                      currentValue: currentValue,
                    ),
                    const SizedBox(height: 12),
                    _apontamentoOption(
                      title: 'Por OS (Elemento)',
                      subtitle: 'Operador controla produção no nível da OS/Elemento',
                      icon: Icons.view_list_outlined,
                      value: 'por_os',
                      currentValue: currentValue,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _apontamentoOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required String currentValue,
  }) {
    final isSelected = value == currentValue;
    final color = isSelected ? AppColors.secondary : Colors.grey[400]!;
    return InkWell(
      onTap: () => PreferencesService.apontamentoProducaoCD.add(value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? color : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}
