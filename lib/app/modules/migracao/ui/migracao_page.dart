import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/modules/migracao/migracao_controller.dart';
import 'package:aco_plus/app/core/components/empty_data.dart';
import 'package:flutter/material.dart';

class MigracaoPage extends StatefulWidget {
  const MigracaoPage({super.key});

  @override
  State<MigracaoPage> createState() => _MigracaoPageState();
}

class _MigracaoPageState extends State<MigracaoPage> {
  final controller = MigracaoController();

  @override
  void initState() {
    controller.init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Migração de Dados (Legado)')),
      body: StreamBuilder<bool>(
        stream: controller.isLoading.listen,
        builder: (context, snapLoading) {
          final isLoading = snapLoading.data ?? false;
          return IgnorePointer(
            ignoring: isLoading,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (isLoading)
                  const LinearProgressIndicator(),
                StreamBuilder<String>(
                  stream: controller.statusText.listen,
                  builder: (context, snap) {
                    if (snap.data?.isEmpty ?? true) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        snap.data!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }
                ),
                _buildCard(
                  title: 'Importar Pedidos por Etapa',
                  description: 'Busca pedidos legados de uma determinada etapa no Firebase e os envia para uma etapa escolhida no Supabase.',
                  child: _buildImportacaoPedidos(),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildImportacaoPedidos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<List<StepModel>>(
          stream: controller.etapasLegadas.listen,
          builder: (context, snapEtapas) {
            final etapas = snapEtapas.data ?? [];
            // Resolve o value pela lista atual (por ID) para evitar assertion do DropdownButton
            final valorAtual = etapas.where((e) =>
                e.id == controller.etapaOrigemSelecionada?.id).firstOrNull;
            return Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<StepModel>(
                    decoration: const InputDecoration(labelText: 'Etapa de Origem (Firebase)'),
                    value: valorAtual,
                    hint: etapas.isEmpty
                        ? const Text('Clique em "Buscar" para conectar ao Firebase')
                        : const Text('Selecione a etapa de origem'),
                    items: etapas
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                        .toList(),
                    onChanged: etapas.isEmpty
                        ? null
                        : (val) {
                            setState(() {
                              controller.etapaOrigemSelecionada = val;
                            });
                          },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    // Se etapas ainda não foram carregadas, busca primeiro (inicializa Firebase)
                    if (etapas.isEmpty) {
                      await controller.buscarEtapasLegadas();
                      return;
                    }
                    if (controller.etapaOrigemSelecionada != null) {
                      controller.buscarPedidosLegados(controller.etapaOrigemSelecionada!);
                    }
                  },
                  child: Text(etapas.isEmpty ? 'Conectar Firebase' : 'Buscar Pedidos'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        StreamBuilder<String>(
          stream: controller.logMatchIds.listen,
          builder: (context, snapLog) {
            if (snapLog.data?.isEmpty ?? true) return const SizedBox();
            return Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: snapLog.data!.contains('✅') ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                snapLog.data!,
                style: TextStyle(
                  color: snapLog.data!.contains('✅') ? Colors.green.shade900 : Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
        ),
        StreamBuilder<List<PedidoModel>>(
          stream: controller.pedidosLegados.listen,
          builder: (context, snapLegados) {
            final legados = snapLegados.data ?? [];
            if (legados.isEmpty) return const EmptyData();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdown de etapa destino fixo no topo
                DropdownButtonFormField<StepModel>(
                  decoration: const InputDecoration(labelText: 'Etapa de Destino (Supabase)'),
                  value: controller.etapaDestinoSelecionada,
                  items: BackendClient.steps.data
                      .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => controller.etapaDestinoSelecionada = val);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  '${legados.length} pedido(s) encontrado(s) — clique em Importar para enviar um por vez',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 8),
                StreamBuilder<bool>(
                  stream: controller.isLoading.listen,
                  builder: (context, snapLoading) {
                    final loading = snapLoading.data ?? false;
                    return Container(
                      height: 380,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        itemCount: legados.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                        itemBuilder: (context, index) {
                          final pedido = legados[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(
                              pedido.localizador,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${pedido.cliente.nome}${pedido.descricao.isNotEmpty ? ' · ${pedido.descricao}' : ''}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: (loading || controller.etapaDestinoSelecionada == null)
                                  ? null
                                  : () => controller.importarPedidoUnico(
                                      pedido,
                                      controller.etapaDestinoSelecionada!,
                                      context,
                                    ),
                              icon: const Icon(Icons.upload, size: 16),
                              label: const Text('Importar'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontSize: 13),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }
                ),
              ],
            );
          }
        ),
        // Banner de sucesso
        StreamBuilder<bool>(
          stream: controller.importacaoConcluida.listen,
          builder: (context, snap) {
            if (!(snap.data ?? false)) return const SizedBox();
            return Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StreamBuilder<String>(
                      stream: controller.statusText.listen,
                      builder: (context, s) => Text(
                        s.data ?? '',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCard({required String title, required String description, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
