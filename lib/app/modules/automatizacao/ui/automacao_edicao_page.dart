import 'dart:async';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automacao_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/divisor.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/dialogs/info_dialog.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/models/text_controller.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:flutter/material.dart';

class AutomacaoEdicaoPage extends StatefulWidget {
  final AutomacaoModel automacao;
  const AutomacaoEdicaoPage(this.automacao, {super.key});

  @override
  State<AutomacaoEdicaoPage> createState() => _AutomacaoEdicaoPageState();
}

class _AutomacaoEdicaoPageState extends State<AutomacaoEdicaoPage> {
  final TextController _nomeCtrl = TextController();
  final TextController _descCtrl = TextController();
  final TextController _indexCtrl = TextController();
  List<StepModel> _selectedSteps = [];
  bool _isEdit = false;

  @override
  void initState() {
    _isEdit = widget.automacao.nome.isNotEmpty;
    _nomeCtrl.text = widget.automacao.nome;
    _descCtrl.text = widget.automacao.descricao;
    _indexCtrl.text = widget.automacao.index.toString();
    _selectedSteps = List.from(widget.automacao.steps);
    setWebTitle(_isEdit ? 'Editar Automação' : 'Nova Automação');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar Automação' : 'Nova Automação'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: () => _onDelete(),
              icon: const Icon(Icons.delete_outline),
            ),
          IconButton(
            onPressed: () => _onSave(),
            icon: const Icon(Icons.check),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppField(
            label: 'Nome da Automação',
            controller: _nomeCtrl,
            onChanged: (_) => setState(() {}),
          ),
          const H(16),
          AppField(
            label: 'Descrição',
            controller: _descCtrl,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
          const H(16),
          AppField(
            label: 'Código Interno (Index)',
            controller: _indexCtrl,
            type: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          const H(32),
          Text('Etapas do Processo', style: AppCss.mediumBold),
          Text(
            'Selecione quais etapas pertencem a esta regra de automação',
            style: AppCss.minimumRegular.setColor(Colors.grey),
          ),
          const H(16),
          _stepsListWidget(),
        ],
      ),
    );
  }

  Widget _stepsListWidget() {
    final allSteps = FirestoreClient.steps.data;
    if (allSteps.isEmpty) {
      return const Center(child: Text('Nenhuma etapa cadastrada no sistema.'));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: allSteps.map((step) {
          final isSelected = _selectedSteps.any((s) => s.id == step.id);
          return Column(
            children: [
              CheckboxListTile(
                value: isSelected,
                title: Text(step.name, style: AppCss.minimumBold),
                subtitle: Text('Index: ${step.index}', style: AppCss.minimumRegular.setSize(10)),
                activeColor: AppColors.primaryMain,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedSteps.add(step);
                    } else {
                      _selectedSteps.removeWhere((s) => s.id == step.id);
                    }
                  });
                },
              ),
              if (allSteps.last.id != step.id) const Divisor(),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _onSave() async {
    if (_nomeCtrl.text.isEmpty) {
      unawaited(showInfoDialog('Por favor, informe o nome.'));
      return;
    }

    final model = widget.automacao.copyWith(
      nome: _nomeCtrl.text,
      descricao: _descCtrl.text,
      index: int.tryParse(_indexCtrl.text) ?? 0,
      steps: _selectedSteps,
    );

    if (_isEdit) {
      await FirestoreClient.automacoes.update(model);
    } else {
      await FirestoreClient.automacoes.add(model);
    }
    if (mounted) pop(context);
  }

  void _onDelete() async {
    final confirm = await showConfirmDialog(
      'Excluir Automação',
      'Deseja realmente excluir esta regra?',
    );
    if (confirm == true) {
      await FirestoreClient.automacoes.delete(widget.automacao.id);
      if (mounted) pop(context);
    }
  }
}
