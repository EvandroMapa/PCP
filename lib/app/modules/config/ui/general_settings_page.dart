import 'dart:typed_data';

import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:aco_plus/app/core/services/supabase_storage_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/logo_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  int _selectedIndex = 0;

  static const _sections = [
    _SidebarItem(icon: Icons.precision_manufacturing_outlined, label: 'Produção'),
    _SidebarItem(icon: Icons.picture_as_pdf_outlined, label: 'Desenho Técnico'),
    _SidebarItem(icon: Icons.dashboard_customize_outlined, label: 'Interface'),
    _SidebarItem(icon: Icons.assignment_outlined, label: 'Apontamento CD'),
    _SidebarItem(icon: Icons.image_outlined, label: 'Logomarca'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Configurações Gerais', style: TextStyle(color: Colors.white)),
      ),
      body: Row(
        children: [
          // ── Sidebar ──
          Container(
            width: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              border: Border(
                right: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                for (int i = 0; i < _sections.length; i++) ...[
                  _sidebarTile(i),
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '71cc',
                    style: TextStyle(color: Colors.grey[300], fontSize: 9),
                  ),
                ),
              ],
            ),
          ),

          // ── Conteúdo ──
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                padding: const EdgeInsets.all(32),
                children: [
                  _sectionTitle(),
                  const SizedBox(height: 24),
                  _sectionContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarTile(int index) {
    final section = _sections[index];
    final isSelected = index == _selectedIndex;
    return Tooltip(
      message: section.label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _selectedIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryMain.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: AppColors.primaryMain.withValues(alpha: 0.20))
                    : null,
              ),
              child: Icon(
                section.icon,
                size: 18,
                color: isSelected
                    ? AppColors.primaryMain
                    : Colors.grey[400],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle() {
    final section = _sections[_selectedIndex];
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
          section.label.toUpperCase(),
          style: AppCss.mediumBold.setSize(16).setColor(AppColors.secondary),
        ),
      ],
    );
  }

  Widget _sectionContent() {
    switch (_selectedIndex) {
      case 0:
        return _productionSettings();
      case 1:
        return _pdfOptimizationSettings();
      case 2:
        return _layoutSettings();
      case 3:
        return _apontamentoSettings();
      case 4:
        return _logoSettings();
      default:
        return const SizedBox.shrink();
    }
  }

  // ═══════════════════════════════════════════════════
  //  PRODUÇÃO
  // ═══════════════════════════════════════════════════
  Widget _productionSettings() {
    return _settingsCard(
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
    );
  }

  // ═══════════════════════════════════════════════════
  //  DESENHO TÉCNICO
  // ═══════════════════════════════════════════════════
  Widget _pdfOptimizationSettings() {
    return _settingsCard(
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
    );
  }

  // ═══════════════════════════════════════════════════
  //  INTERFACE
  // ═══════════════════════════════════════════════════
  Widget _layoutSettings() {
    return _settingsCard(
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
    );
  }

  // ═══════════════════════════════════════════════════
  //  APONTAMENTO CD
  // ═══════════════════════════════════════════════════
  Widget _apontamentoSettings() {
    return _settingsCard(
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
    );
  }

  // ═══════════════════════════════════════════════════
  //  LOGOMARCA
  // ═══════════════════════════════════════════════════
  bool _uploading = false;

  Widget _logoSettings() {
    return _settingsCard(
      child: StreamOut<String>(
        stream: PreferencesService.logoUrl.listen,
        builder: (_, logoUrl) {
          final hasCustom = logoUrl.isNotEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Logomarca do Sistema',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Selecione uma imagem para substituir a logo padrão. '
                'Ela será usada na tela de login, menu lateral, splash e relatórios PDF.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // ── Preview ──
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: LogoHelper.logoWidget(fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasCustom ? 'Logo Personalizada' : 'Logo Padrão',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasCustom ? Colors.green[700] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Ações ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _uploading ? null : _pickAndUploadLogo,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.upload_file_outlined, size: 18),
                    label: Text(_uploading ? 'Enviando...' : 'Selecionar Imagem'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryMain,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                  if (hasCustom) ...[
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _removeLogo,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remover'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        side: BorderSide(color: Colors.red[300]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),
              // ── Dicas ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue[700], size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Recomendações:\n'
                        '• Use imagens PNG com fundo transparente\n'
                        '• Resolução mínima de 200×200 pixels\n'
                        '• Formato quadrado para melhor adaptação',
                        style: TextStyle(fontSize: 12, color: Colors.blue[800], height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) return;

      setState(() => _uploading = true);

      final ext = file.extension ?? 'png';
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';

      final url = await SupabaseStorageService.uploadFile(
        name: 'logo.$ext',
        bytes: bytes,
        mimeType: mime,
        path: 'config',
      );

      PreferencesService.logoUrl.add(url);

      NotificationService.showPositive(
        'Logo atualizada',
        'A logomarca foi salva com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao enviar logo',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeLogo() {
    PreferencesService.logoUrl.add('');
    NotificationService.showPositive(
      'Logo removida',
      'O sistema voltará a usar a logo padrão',
      position: NotificationPosition.bottom,
    );
  }

  // ═══════════════════════════════════════════════════
  //  WIDGETS UTILITÁRIOS
  // ═══════════════════════════════════════════════════
  Widget _settingsCard({required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: child,
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

class _SidebarItem {
  final IconData icon;
  final String label;
  const _SidebarItem({required this.icon, required this.label});
}
