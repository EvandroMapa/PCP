import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/components/app_text_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/pedido/services/pedido_pdf_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

Future<void> showPedidoImportPdfDialog({StepModel? initialStep}) async {
  await showDialog(
    context: contextGlobal,
    barrierDismissible: false,
    builder: (context) => PedidoImportPdfDialog(initialStep: initialStep),
  );
}

class PedidoImportPdfDialog extends StatefulWidget {
  final StepModel? initialStep;
  const PedidoImportPdfDialog({super.key, this.initialStep});

  @override
  State<PedidoImportPdfDialog> createState() => _PedidoImportPdfDialogState();
}

class _PedidoImportPdfDialogState extends State<PedidoImportPdfDialog> {
  int currentStep = 0;
  bool isUploading = false;
  PlatformFile? selectedFile;
  String extractedTextDebug = '';

  final TextEditingController localizadorCtrl = TextEditingController();
  final TextEditingController financeiroCtrl = TextEditingController();
  final TextEditingController descricaoCtrl = TextEditingController();
  final TextEditingController obraCtrl = TextEditingController();
  final TextEditingController planilhamentoCtrl = TextEditingController();
  final TextEditingController romaneioCtrl = TextEditingController();
  final TextEditingController subtotalCtrl = TextEditingController(text: '0,00');
  final TextEditingController taxasCtrl = TextEditingController(text: '0,00');
  final TextEditingController descontoCtrl = TextEditingController(text: '0,00');
  final TextEditingController totalFinalCtrl = TextEditingController(text: '0,00');
  
  DateTime deliveryDate = DateTime.now().add(const Duration(days: 7));
  ClienteModel? selectedCliente;
  PedidoTipo selectedTipo = PedidoTipo.cda;
  StepModel? selectedStep;
  List<Map<String, dynamic>> extractedProducts = [];

  @override
  void initState() {
    super.initState();
    selectedStep = widget.initialStep ?? FirestoreClient.steps.data.firstOrNull;
  }

  void _calculateTotal() {
    final sub = double.tryParse(subtotalCtrl.text.replaceAll(',', '.')) ?? 0;
    final tax = double.tryParse(taxasCtrl.text.replaceAll(',', '.')) ?? 0;
    final desc = double.tryParse(descontoCtrl.text.replaceAll(',', '.')) ?? 0;
    final total = (sub + tax) - desc;
    totalFinalCtrl.text = total.toStringAsFixed(2).replaceAll('.', ',');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        selectedFile = result.files.first;
      });
      _processFile();
    }
  }

  Future<void> _processFile() async {
    if (selectedFile == null || selectedFile!.bytes == null) return;
    
    setState(() => isUploading = true);

    try {
      final PdfDocument document = PdfDocument(inputBytes: selectedFile!.bytes);
      final String extractedText = PdfTextExtractor(document).extractText();
      document.dispose();

      final parsedData = PedidoPdfParser.parse(extractedText);

      setState(() {
        extractedTextDebug = extractedText;
        financeiroCtrl.text = parsedData['pedidoFinanceiro'];
        planilhamentoCtrl.text = parsedData['planilhamento'] ?? '';
        romaneioCtrl.text = parsedData['romaneio'] ?? '';
        
        // BUSCA POR CÓDIGO (NOVO)
        final int code = int.tryParse(parsedData['clienteCodigo']) ?? 0;
        selectedCliente = FirestoreClient.clientes.data.firstWhereOrNull(
          (e) => e.codigo == code,
        ) ?? ClienteModel(
            id: HashService.get, // Novo UUID se não existir
            codigo: code,
            nome: parsedData['clienteNome'],
            telefone: '',
            cpf: '',
            endereco: EnderecoModel.empty(),
            obras: [],
          );
        extractedProducts = List<Map<String, dynamic>>.from(parsedData['produtos']);
        
        subtotalCtrl.text = parsedData['subtotal'].toStringAsFixed(2).replaceAll('.', ',');
        taxasCtrl.text = parsedData['taxas'].toStringAsFixed(2).replaceAll('.', ',');
        descontoCtrl.text = parsedData['desconto'].toStringAsFixed(2).replaceAll('.', ',');
        totalFinalCtrl.text = parsedData['total'].toStringAsFixed(2).replaceAll('.', ',');
        
        _calculateTotal();
        currentStep = 1;
      });
    } catch (e) {
      NotificationService.showNegative('Erro', 'Falha ao processar PDF: $e');
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _handleReimport() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Reimportação'),
        content: const Text('Deseja importar um novo PDF? Os dados preenchidos até agora nesta janela serão perdidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sim, trocar PDF', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok == true) {
      _pickFile();
    }
  }

  Future<void> _generateCard() async {
    if (localizadorCtrl.text.trim().isEmpty) {
      NotificationService.showNegative('Atenção', 'O campo Localizador é obrigatório.');
      return;
    }
    
    if (selectedStep == null) {
      NotificationService.showNegative('Erro', 'Selecione uma etapa para o pedido.');
      return;
    }

    setState(() => isUploading = true);

    try {
      // LÓGICA DE CLIENTE: Verificar se já existe pelo código
      ClienteModel finalCliente = selectedCliente ?? ClienteModel.empty();

      // Busca atualizada na base de dados para garantir
      final existing = FirestoreClient.clientes.data.firstWhereOrNull(
        (e) => e.codigo == finalCliente.codigo && finalCliente.codigo > 0,
      );

      if (existing == null && finalCliente.codigo > 0) {
        // Cadastrar novo cliente
        await AppSupabaseClient.clientes.add(finalCliente);
      } else if (existing != null) {
        finalCliente = existing;
      }

      final List<String> missingProducts = [];
      final List<PedidoProdutoModel> produtosMapped = [];
      
      for (final p in extractedProducts) {
        final produtoBase = FirestoreClient.produtos.data.firstWhereOrNull(
          (e) => e.codigoFinanceiro == p['codigo'],
        );

        if (produtoBase == null) {
          missingProducts.add('${p['codigo']} - ${p['descricao']}');
        } else {
          produtosMapped.add(PedidoProdutoModel(
            id: HashService.get,
            pedidoId: '', 
            clienteId: finalCliente.id, 
            obraId: '',
            produto: produtoBase,
            statusess: [PedidoProdutoStatusModel.empty()],
            qtde: p['qtde'],
            valorUnitario: p['unitario'],
            valorTotal: p['total'],
          ));
        }
      }

      if (missingProducts.isNotEmpty) {
        final bool? proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Produtos não Cadastrados'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Os itens destacados em vermelho não existem na base de dados.'),
                const H(12),
                Text('Deseja criar o pedido desconsiderando estes itens?', style: AppCss.minimumBold),
                const H(16),
                Text('Itens que serão ignorados:', style: AppCss.minimumRegular.setSize(11)),
                const H(4),
                ...missingProducts.take(5).map((e) => Text('• $e', style: AppCss.minimumBold.setSize(11).setColor(Colors.red))),
                if (missingProducts.length > 5) Text('... e mais ${missingProducts.length - 5} itens.', style: AppCss.minimumRegular.setSize(11)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), 
                child: Text('CANCELAR', style: AppCss.minimumRegular.setColor(AppColors.neutralDark)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true), 
                child: Text('SIM, CRIAR SEM ESTES ITENS', style: AppCss.minimumBold.setColor(AppColors.primaryDark)),
              ),
            ],
          ),
        );

        if (proceed != true) {
          setState(() => isUploading = false);
          return;
        }

        if (produtosMapped.isEmpty) {
          NotificationService.showNegative('Erro', 'Não é possível criar um pedido sem nenhum item válido.');
          setState(() => isUploading = false);
          return;
        }
      }

      // Cálculo de totais baseado nos itens que serão realmente salvos
      double vSubtotal = 0;
      for (var pm in produtosMapped) {
        vSubtotal += pm.valorTotal;
      }

      final double vTaxas = double.tryParse(taxasCtrl.text.replaceAll(',', '.')) ?? 0;
      final double vDesconto = double.tryParse(descontoCtrl.text.replaceAll(',', '.')) ?? 0;
      final double vTotal = vSubtotal + vTaxas - vDesconto;

      final pedido = PedidoModel.empty().copyWith(
        id: HashService.get,
        localizador: localizadorCtrl.text,
        pedidoFinanceiro: financeiroCtrl.text,
        planilhamento: planilhamentoCtrl.text,
        romaneio: romaneioCtrl.text,
        descricao: descricaoCtrl.text,
        deliveryAt: deliveryDate,
        cliente: finalCliente,
        tipo: selectedTipo,
        statusess: [PedidoStatusModel.create(PedidoStatus.aguardandoProducaoCDA)],
        steps: [PedidoStepModel.create(selectedStep!)],
        valorSubtotal: vSubtotal,
        valorTaxas: vTaxas,
        valorDesconto: vDesconto,
        valorTotal: vTotal,
      );

      await AppSupabaseClient.pedidos.add(pedido);
      
      for (final p in produtosMapped) {
        final finalProd = p.copyWith(
          pedidoId: pedido.id,
          clienteId: pedido.cliente.id,
          obraId: pedido.obra.id,
        );
        await AppSupabaseClient.pedidoProdutos.add(finalProd);
      }

      if (mounted) {
        Navigator.pop(context);
        NotificationService.showPositive('Sucesso', 'Pedido gerado com sucesso!');
      }
    } catch (e) {
      NotificationService.showNegative('Erro', 'Falha ao salvar: $e');
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppCss.radius12),
      child: Container(
        width: 800,
        height: 850,
        decoration: BoxDecoration(color: Colors.white, borderRadius: AppCss.radius12),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: currentStep == 0 ? _buildUploadStep() : _buildConferenceStep()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryMain,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.white),
          const W(12),
          Text(
            currentStep == 0 ? 'IMPORTAR PEDIDO (PDF)' : 'CONFERÊNCIA DE DADOS',
            style: AppCss.mediumBold.setColor(Colors.white),
          ),
          if (currentStep == 1 && !isUploading) ...[
            const W(16),
            InkWell(
              onTap: _handleReimport,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  borderRadius: AppCss.radius4,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.refresh, color: Colors.white, size: 14),
                    const W(4),
                    Text('IMPORTAR NOVO PDF', style: AppCss.minimumBold.setSize(10).setColor(Colors.white)),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(),
          if (!isUploading)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: _pickFile,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.primaryMain.withValues(alpha: 0.05),
                borderRadius: AppCss.radius12,
                border: Border.all(color: AppColors.primaryMain.withValues(alpha: 0.3), width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 64, color: AppColors.primaryMain),
                  const H(16),
                  Text('Selecione o PDF do pedido', style: AppCss.mediumBold),
                ],
              ),
            ),
          ),
          if (isUploading) ...[
            const H(24),
            const CircularProgressIndicator(),
          ]
        ],
      ),
    );
  }

  Widget _buildConferenceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildStepSelector()),
              const W(12),
              Expanded(child: _buildField('Localizador (*)', localizadorCtrl, color: Colors.blue.shade900)),
            ],
          ),
          const H(12),
          Row(
            children: [
              Expanded(child: _buildField('Pedido Financeiro', financeiroCtrl)),
              const W(12),
              Expanded(child: _buildField('Tipo', null, dropdown: _buildTipoDropdown())),
            ],
          ),
          const H(12),
          Row(
            children: [
              Expanded(child: _buildField('Planilhamento', planilhamentoCtrl)),
              const W(12),
              Expanded(child: _buildField('Romaneio', romaneioCtrl)),
            ],
          ),
          const H(12),
           Row(
            children: [
               Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data de Entrega', style: AppCss.minimumBold.setSize(12)),
                    const H(4),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: deliveryDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) setState(() => deliveryDate = date);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(border: Border.all(color: AppColors.neutralLight), borderRadius: AppCss.radius8),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const W(8),
                            Text(DateFormat('dd/MM/yyyy').format(deliveryDate)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const W(12),
              const Spacer(),
            ],
          ),
          const H(12),
          _buildField('Cliente', TextEditingController(text: '${selectedCliente?.codigo} - ${selectedCliente?.nome}')),
          const H(12),
          Row(
            children: [
              Expanded(child: _buildField('Obra', obraCtrl)),
              const W(12),
              Expanded(child: _buildField('Descrição', descricaoCtrl)),
            ],
          ),
          const H(16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.neutralLight.withValues(alpha: 0.2), 
              borderRadius: AppCss.radius12,
            ),
            child: Row(
              children: [
                Expanded(child: _buildField('Subtotal', subtotalCtrl, onChanged: (_) => _calculateTotal())),
                const W(12),
                Expanded(child: _buildField('Taxas', taxasCtrl, onChanged: (_) => _calculateTotal())),
                const W(12),
                Expanded(child: _buildField('Desconto', descontoCtrl, onChanged: (_) => _calculateTotal())),
                const W(12),
                Expanded(child: _buildField('TOTAL', totalFinalCtrl, color: Colors.green.shade900, readOnly: true)),
              ],
            ),
          ),
          const H(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ITENS (${extractedProducts.length})', style: AppCss.mediumBold),
              if (extractedProducts.isEmpty)
                Text('Nenhum produto detectado!', style: AppCss.minimumBold.setColor(Colors.red)),
            ],
          ),
          const H(8),
          if (extractedProducts.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber),
                borderRadius: AppCss.radius8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('O robô não conseguiu ler os produtos automaticamente. Por favor, copie o texto abaixo e envie para o suporte:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const H(8),
                  SelectableText(
                    extractedTextDebug,
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace'),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(border: Border.all(color: AppColors.neutralLight), borderRadius: AppCss.radius8),
              child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: extractedProducts.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.neutralLight),
              itemBuilder: (context, index) {
                final p = extractedProducts[index];
                final produtoBase = FirestoreClient.produtos.data.firstWhereOrNull(
                  (e) => e.codigoFinanceiro.trim().toLowerCase() == p['codigo'].toString().trim().toLowerCase(),
                );
                final bool exists = produtoBase != null;
                
                final String pdfName = p['descricao'] ?? '';
                final double vUnit = p['unitario'] ?? 0;
                final double vTotal = p['total'] ?? 0;
                final String fUnit = NumberFormat.simpleCurrency(locale: 'pt_BR').format(vUnit);
                final String fTotal = NumberFormat.simpleCurrency(locale: 'pt_BR').format(vTotal);
                
                return ListTile(
                  leading: Icon(Icons.shopping_basket_outlined, color: exists ? Colors.green : Colors.red),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exists ? '${p['codigo']} - ${produtoBase.nome}' : '${p['codigo']} - ITEM NÃO CADASTRADO NA BASE DE DADOS',
                        style: TextStyle(
                          color: exists ? Colors.black : Colors.red, 
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        )
                      ),
                      if (pdfName.isNotEmpty)
                        Text(
                          ' ($pdfName)',
                          style: AppCss.minimumRegular.setSize(11).setColor(Colors.black),
                        ),
                    ],
                  ),
                  subtitle: Text('Qtde: ${p['qtde']} | V.Unit: $fUnit | Total: $fTotal'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Etapa Destino', style: AppCss.minimumBold.setSize(12)),
        const H(4),
        DropdownButtonFormField<StepModel>(
          value: selectedStep,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(borderRadius: AppCss.radius8),
          ),
          onChanged: (e) => setState(() => selectedStep = e),
          items: FirestoreClient.steps.data.map((e) => DropdownMenuItem(
            value: e, 
            child: Text(e.name, style: AppCss.minimumBold.setSize(14))
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildTipoDropdown() {
    return DropdownButtonFormField<PedidoTipo>(
      value: selectedTipo,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(borderRadius: AppCss.radius8),
      ),
      onChanged: (e) => setState(() => selectedTipo = e!),
      items: PedidoTipo.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
    );
  }

  Widget _buildField(String label, TextEditingController? ctrl, {Color? color, bool readOnly = false, Function(String)? onChanged, Widget? dropdown}) {
    String? val;
    if (ctrl != null && (label.toLowerCase().contains('total') || label.toLowerCase().contains('subtotal') || label.toLowerCase().contains('taxas') || label.toLowerCase().contains('desconto'))) {
      final double num = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
      val = NumberFormat.simpleCurrency(locale: 'pt_BR').format(num);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppCss.minimumBold.setSize(12)),
        const H(4),
        dropdown ?? TextField(
          controller: val != null ? TextEditingController(text: val) : ctrl,
          readOnly: readOnly || val != null, // Campos financeiros formatados ficam somente leitura ou precisam de máscara real
          onChanged: onChanged,
          style: TextStyle(color: color, fontWeight: color != null ? FontWeight.bold : null),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: AppCss.radius8),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: AppTextButton.outlined(label: 'Cancelar', onPressed: () => Navigator.pop(context), isEnable: !isUploading)),
          const W(12),
          if (currentStep == 1)
            Expanded(child: AppTextButton(label: 'Gerar Cartão', onPressed: _generateCard, isEnable: !isUploading)),
        ],
      ),
    );
  }
}
