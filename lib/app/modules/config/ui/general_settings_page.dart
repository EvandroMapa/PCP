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
        backgroundColor: AppColors.primaryMain,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _sectionHeader('Produção'),
          const SizedBox(height: 16),
          _productionSettings(),
          const SizedBox(height: 32),
          _sectionHeader('Interface'),
          const SizedBox(height: 16),
          _layoutSettings(),
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
            color: AppColors.primaryMain,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title.toUpperCase(),
          style: AppCss.mediumBold.setSize(16).setColor(AppColors.primaryDark),
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
                      onPressed: value > 0 
                          ? () => PreferencesService.maxElementosProducao.add(value - 1)
                          : null,
                    ),
                    const SizedBox(width: 24),
                    Container(
                      width: 100,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                      ),
                      child: Text(
                        value.toString(),
                        style: AppCss.largeBold.setSize(28).setColor(AppColors.secondary),
                      ),
                    ),
                    const SizedBox(width: 24),
                    _numericButton(
                      icon: Icons.add,
                      onPressed: value < 99 
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

  Widget _numericButton({required IconData icon, VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.primaryMain),
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
                        color: Colors.blue.withOpacity(0.1),
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
}
