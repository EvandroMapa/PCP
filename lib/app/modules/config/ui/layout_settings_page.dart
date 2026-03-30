import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:flutter/material.dart';

class LayoutSettingsPage extends StatelessWidget {
  const LayoutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Configurações de Layout', style: TextStyle(color: Colors.white)),
      ),
      body: StreamOut<double>(
        stream: PreferencesService.kanbanColumnWidth.listen,
        builder: (context, width) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Largura das Colunas do Kanban',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Arraste o controle deslizante abaixo para ajustar a largura padrão de todas as etapas no painel do Kanban. A configuração é salva e aplicada apenas neste dispositivo.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Text('Estreito\n(200px)', textAlign: TextAlign.center),
                    Expanded(
                      child: Slider(
                        value: width,
                        min: 200,
                        max: 600,
                        divisions: 40,
                        label: '${width.round()} px',
                        onChanged: (value) {
                          PreferencesService.kanbanColumnWidth.add(value);
                        },
                      ),
                    ),
                    const Text('Largo\n(600px)', textAlign: TextAlign.center),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Tamanho atual: ${width.round()} px',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
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
}
