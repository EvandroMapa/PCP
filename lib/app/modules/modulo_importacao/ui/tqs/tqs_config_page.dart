import 'dart:developer';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:flutter/material.dart';

class TqsConfigPage extends StatefulWidget {
  const TqsConfigPage({super.key});

  @override
  State<TqsConfigPage> createState() => _TqsConfigPageState();
}

class _TqsConfigPageState extends State<TqsConfigPage> {
  bool _habilitado = false;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    setWebTitle('AçoPlus - Planejamento e controle de Produção');
    _carregarEstado();
  }

  Future<void> _carregarEstado() async {
    try {
      final response = await SupabaseService.client
          .from('modulos_importacao')
          .select()
          .eq('id', 'tqs')
          .maybeSingle();

      if (response != null) {
        setState(() {
          _habilitado = response['habilitado'] == true;
          _carregando = false;
        });
      } else {
        // Cria registro se não existir
        await SupabaseService.client.from('modulos_importacao').insert({
          'id': 'tqs',
          'habilitado': false,
          'config': {},
        });
        setState(() => _carregando = false);
      }
    } catch (e) {
      log('TqsConfigPage._carregarEstado erro: $e');
      setState(() => _carregando = false);
    }
  }

  Future<void> _toggleHabilitado(bool valor) async {
    setState(() => _habilitado = valor);
    try {
      debugPrint('TqsConfigPage: salvando habilitado=$valor...');
      await SupabaseService.client
          .from('modulos_importacao')
          .upsert({
            'id': 'tqs',
            'habilitado': valor,
            'config': {},
            'updated_at': DateTime.now().toIso8601String(),
          });

      debugPrint('TqsConfigPage: salvo com sucesso!');
      NotificationService.showPositive(
        valor ? 'Módulo Habilitado' : 'Módulo Desabilitado',
        valor
            ? 'TQS disponível no botão Importar dos pedidos'
            : 'TQS removido do menu de importação',
      );
    } catch (e) {
      log('TqsConfigPage._toggleHabilitado erro: $e');
      debugPrint('TqsConfigPage: ERRO ao salvar: $e');
      setState(() => _habilitado = !valor); // reverte
      NotificationService.showNegative(
        'Erro',
        'Falha ao salvar configuração: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          'TQS - Configurações',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        backgroundColor: AppColors.primaryMain,
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      backgroundColor: AppColors.neutralLightest,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabeçalho do módulo com toggle ────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (_habilitado
                                ? const Color(0xFF10B981)
                                : Colors.grey[400]!)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.table_chart_rounded,
                        size: 24,
                        color: _habilitado
                            ? const Color(0xFF10B981)
                            : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Módulo TQS',
                            style: AppCss.mediumBold.setColor(AppColors.black),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Importa elementos exportados pelo relatório TQS Planilhar via CSV. '
                            'Não importa pesos totais por bitola.',
                            style: AppCss.minimumRegular
                                .setColor(AppColors.neutralMedium)
                                .setSize(13),
                          ),
                        ],
                      ),
                    ),
                    if (_carregando)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Switch(
                        value: _habilitado,
                        onChanged: _toggleHabilitado,
                        activeColor: AppColors.primaryMain,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Info do módulo ─────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _habilitado
                    ? Container(
                        key: const ValueKey('habilitado'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: Colors.green[700], size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Módulo ativo',
                                    style: AppCss.smallBold
                                        .setColor(Colors.green[800]!),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'O botão "Importar" no título de cada pedido incluirá a opção TQS. '
                                    'Importa elementos e posições exportados pelo relatório TQS Planilhar '
                                    'a partir de um arquivo CSV. Não importa pesos totais por bitola.',
                                    style: AppCss.minimumRegular
                                        .setColor(Colors.green[700]!)
                                        .setSize(12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        key: const ValueKey('desabilitado'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.red[400], size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Módulo desativado',
                                    style: AppCss.smallBold
                                        .setColor(Colors.red[700]!),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Habilite o módulo para que a opção TQS apareça '
                                    'no menu de importação dos pedidos.',
                                    style: AppCss.minimumRegular
                                        .setColor(Colors.red[400]!)
                                        .setSize(12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // ── Informações sobre o formato CSV ────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Formato do CSV aceito',
                          style: AppCss.smallBold
                              .setColor(Colors.grey[800]!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Colunas obrigatórias: ELEMENTO, POSICAO, BITOLA, PESO\n'
                      'Colunas opcionais: QTDE ELEM, OS, QTDE, COMPR UNIT, COMPR CORTE, ID ELEM\n\n'
                      'Dica: Salve sua planilha como "CSV UTF-8" (separado por ponto-e-vírgula).',
                      style: AppCss.minimumRegular
                          .setColor(Colors.grey[600]!)
                          .setSize(12),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // ── Rodapé informativo ────────────────────────────────────────
              Center(
                child: Text(
                  'Módulo de importação TQS v1.0',
                  style: AppCss.minimumRegular
                      .setColor(Colors.grey[400]!)
                      .setSize(11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
