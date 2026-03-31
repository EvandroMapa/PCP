import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automacao_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/automatizacao/ui/automacao_edicao_page.dart';
import 'package:flutter/material.dart';

class AutomacoesPage extends StatefulWidget {
  const AutomacoesPage({super.key});

  @override
  State<AutomacoesPage> createState() => _AutomacoesPageState();
}

class _AutomacoesPageState extends State<AutomacoesPage> {
  @override
  void initState() {
    setWebTitle('Automação');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Automação'),
      ),
      fab: FloatingActionButton(
        onPressed: () => push(context, AutomacaoEdicaoPage(AutomacaoModel.empty())),
        backgroundColor: AppColors.primaryMain,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamOut<List<AutomacaoModel>>(
        stream: FirestoreClient.automacoes.dataStream.listen,
        builder: (_, automacoes) {
          if (automacoes.isEmpty) {
            return Center(
              child: Text(
                'Nenhuma automação cadastrada',
                style: AppCss.minimumRegular.setColor(Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: automacoes.length,
            separatorBuilder: (_, __) => const Divisor(),
            itemBuilder: (_, index) {
              final automacao = automacoes[index];
              return ListTile(
                onTap: () => push(context, AutomacaoEdicaoPage(automacao)),
                title: Text(automacao.nome, style: AppCss.mediumBold),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (automacao.descricao.isNotEmpty)
                      Text(automacao.descricao, style: AppCss.minimumRegular),
                    Text('Código Interno: ${automacao.index}',
                        style: AppCss.minimumBold.setSize(10).setColor(Colors.grey)),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              );
            },
          );
        },
      ),
    );
  }
}
