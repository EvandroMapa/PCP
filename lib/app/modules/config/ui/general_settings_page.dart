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
        padding: const EdgeInsets.all(16.0),
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
                return Column(
                  children: [
                    Row(
                      children: [
                        const Text('0', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Slider(
                            value: value.toDouble(),
                            min: 0,
                            max: 99,
                            divisions: 99,
                            label: value.toString(),
                            onChanged: (v) => PreferencesService.maxElementosProducao.add(v.round()),
                          ),
                        ),
                        const Text('99', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'LIMITE ATUAL: $value ELEMENTOS',
                        style: AppCss.mediumBold.setColor(AppColors.secondary),
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

  Widget _layoutSettings() {
    return ExpansionTile(
      leading: const Icon(Icons.dashboard_customize_outlined),
      title: const Text('Ajustes de Layout'),
      subtitle: const Text('Personalize a visualização do sistema'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      childrenPadding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Largura das Colunas do Kanban',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
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
                Text(
                  'Tamanho atual: ${width.round()} px',
                  style: AppCss.smallBold.setColor(AppColors.primaryMain),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
