import 'dart:convert';
import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_status.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/enums/pedido_tipo.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_arquivo_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_status_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/components/app_shimmer.dart';
import 'package:aco_plus/app/core/components/app_text_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/services/hash_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/pedido/services/pedido_pdf_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showPedidoImportPdfDialog() async {
  await showDialog(
    context: contextGlobal,
    barrierDismissible: false,
    builder: (context) => const PedidoImportPdfDialog(),
  );
}

class PedidoImportPdfDialog extends StatefulWidget {
  const PedidoImportPdfDialog({super.key});

  @override
  State<PedidoImportPdfDialog> createState() => _PedidoImportPdfDialogState();
}

class _PedidoImportPdfDialogState extends State<PedidoImportPdfDialog> {
  int currentStep = 0;
  bool isUploading = false;
  PlatformFile? selectedFile;

  // Form Fields
  final TextEditingController localizadorCtrl = TextEditingController();
  final TextEditingController financeiroCtrl = TextEditingController();
  final TextEditingController descricaoCtrl = TextEditingController();
  final TextEditingController obraCtrl = TextEditingController();
  final TextEditingController subtotalCtrl = TextEditingController(text: '0,00');
  final TextEditingController taxasCtrl = TextEditingController(text: '0,00');
  final TextEditingController descontoCtrl = TextEditingController(text: '0,00');
  final TextEditingController totalFinalCtrl = TextEditingController(text: '0,00');
  
  DateTime deliveryDate = DateTime.now().add(const Duration(days: 7));
  ClienteModel? selectedCliente;
  PedidoTipo selectedTipo = PedidoTipo.cda;
  List<Map<String, dynamic>> extractedProducts = [];

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
    if (selectedFile == null) return;
    
    setState(() => isUploading = true);

    try {
      // Simulação: Texto que seria extraído do PDF Baseado nas Imagens
      String simulatedText = """
      Pedido : 25799
      Cliente:
      3544 - Gabriel Wagner Santos Teixeira
      109501 VERGALHAO 5,0 MM PA CD CDA 12.FAT2-CD KG 271,62 7,50 2.037,15
      109499 VERGALHAO 10,0 MM 3/8 PA CD CDA 12.FAT2-CD KG 672,77 6,30 4.238,45
      
      Subtotal : 8.562,82
      Taxas: 0,00
      Desconto : 182,82
      Total : 8.380,00
      """;

      final parsedData = PedidoPdfParser.parse(simulatedText);

      setState(() {
        financeiroCtrl.text = parsedData['pedidoFinanceiro'];
        final clienteId = parsedData['clienteCodigo'];
        selectedCliente = FirestoreClient.clientes.data.firstWhere(
          (e) => e.id == clienteId,
          orElse: () => ClienteModel(
            id: clienteId,
            nome: parsedData['clienteNome'],
            fantasia: parsedData['clienteNome'],
            cpfCnpj: '',
            status: true,
            obras: [],
          ),
        );
        extractedProducts = List<Map<String, dynamic>>.from(parsedData['produtos']);
        
        subtotalCtrl.text = parsedData['subtotal'].toStringAsFixed(2).replaceAll('.', ',');
        taxasCtrl.text = parsedData['taxas'].toStringAsFixed(2).replaceAll('.', ',');
        descontoCtrl.text = parsedData['desconto'].toStringAsFixed(2).replaceAll('.', ',');
        totalFinalCtrl.text = parsedData['total'].toStringAsFixed(2).replaceAll('.', ',');
        
        currentStep = 1;
      });
    } catch (e) {
      NotificationService.showNegative('Erro', 'Falha ao processar PDF: $e');
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _generateCard() async {
    setState(() => isUploading = true);

    try {
      // 0. Validação Rigorosa: Todos os produtos devem existir
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
            clienteId: '', 
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
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Bloqueio de Importação'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('O PDF não pode ser importado pois os seguintes produtos não possuem vínculo financeiro (Código Financeiro):'),
                  const H(12),
                  ...missingProducts.map((e) => Text('• $e', style: AppCss.minimumBold.setSize(12).setColor(Colors.red))),
                  const H(12),
                  const Text('Dica: Cadastre o código financeiro no cadastro de produtos antes de tentar novamente.'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
              ],
            ),
          );
        }
        setState(() => isUploading = false);
        return;
      }

      if (selectedCliente != null) {
        final existing = FirestoreClient.clientes.getById(selectedCliente!.id);
        if (existing.id == 'NOTFOUND') {
          await AppSupabaseClient.clientes.add(selectedCliente!);
        }
      }

      final double vSubtotal = double.tryParse(subtotalCtrl.text.replaceAll(',', '.')) ?? 0;
      final double vTaxas = double.tryParse(taxasCtrl.text.replaceAll(',', '.')) ?? 0;
      final double vDesconto = double.tryParse(descontoCtrl.text.replaceAll(',', '.')) ?? 0;
      final double vTotal = double.tryParse(totalFinalCtrl.text.replaceAll(',', '.')) ?? 0;

      final pedido = PedidoModel.empty().copyWith(
        localizador: localizadorCtrl.text,
        pedidoFinanceiro: financeiroCtrl.text,
        descricao: descricaoCtrl.text,
        deliveryAt: deliveryDate,
        cliente: selectedCliente ?? ClienteModel.empty(),
        tipo: selectedTipo,
        statusess: [PedidoStatusModel.create(PedidoStatus.aguardandoProducaoCDA)],
        steps: [PedidoStepModel.create(FirestoreClient.steps.data.first)],
        valorSubtotal: vSubtotal,
        valorTaxas: vTaxas,
        valorDesconto: vDesconto,
        valorTotal: vTotal,
      );

      final List<PedidoProdutoModel> finalProdutos = produtosMapped.map((p) => p.copyWith(
        pedidoId: pedido.id,
        clienteId: pedido.cliente.id,
      )).toList();

      await AppSupabaseClient.pedidos.add(pedido);
      for (final p in finalProdutos) {
        await AppSupabaseClient.pedidoProdutos.add(p);
      }

      if (mounted) {
        Navigator.pop(context);
        NotificationService.showPositive('Sucesso', 'Pedido e itens gerados com totais financeiros!');
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
            currentStep == 0 ? 'IMPORTAR PEDIDO (PDF)' : 'VALIDAÇÃO E TOTAIS DO PDF',
            style: AppCss.mediumBold.setColor(Colors.white),
          ),
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
                  Text('Clique para selecionar o PDF do pedido', style: AppCss.mediumBold),
                  const H(8),
                  Text('Validação rigorosa de itens e totais financeiros', style: AppCss.minimumRegular),
                ],
              ),
            ),
          ),
          if (isUploading) ...[
            const H(24),
            const CircularProgressIndicator(),
            const H(8),
            const Text('Analisando documento...'),
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
              Expanded(child: _buildField('Localizador', localizadorCtrl)),
              const W(12),
              Expanded(child: _buildField('Pedido Financeiro', financeiroCtrl)),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tipo do Pedido', style: AppCss.minimumBold.setSize(12)),
                    const H(4),
                    DropdownButtonFormField<PedidoTipo>(
                      value: selectedTipo,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(borderRadius: AppCss.radius8),
                      ),
                      onChanged: (e) => setState(() => selectedTipo = e!),
                      items: PedidoTipo.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name.toUpperCase()))).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const H(12),
          _buildField('Cliente (ID - Nome)', TextEditingController(text: '${selectedCliente?.id} - ${selectedCliente?.nome}')),
          const H(12),
          Row(
            children: [
              Expanded(child: _buildField('Obra / Local de Entrega', obraCtrl)),
              const W(12),
              Expanded(child: _buildField('Descrição / Observação', descricaoCtrl)),
            ],
          ),
          const H(16),
          // Finance Summary Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.neutralLight.withValues(alpha: 0.2), 
              borderRadius: AppCss.radius12,
              border: Border.all(color: AppColors.neutralLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                   children: [
                     const Icon(Icons.payments_outlined, size: 18, color: Colors.blue),
                     const W(8),
                     Text('RESUMO FINANCEIRO DO PEDIDO', style: AppCss.minimumBold.setSize(12).setColor(Colors.blue.shade900)),
                   ],
                ),
                const H(12),
                Row(
                  children: [
                    Expanded(child: _buildField('Subtotal', subtotalCtrl, onChanged: (_) => _calculateTotal())),
                    const W(12),
                    Expanded(child: _buildField('Taxas (+)', taxasCtrl, onChanged: (_) => _calculateTotal())),
                    const W(12),
                    Expanded(child: _buildField('Desconto (-)', descontoCtrl, onChanged: (_) => _calculateTotal())),
                    const W(12),
                    Expanded(child: _buildField('TOTAL FINAL', totalFinalCtrl, color: Colors.green.shade900, readOnly: true)),
                  ],
                ),
              ],
            ),
          ),
          const H(20),
          Text('ITENS DO PEDIDO (${extractedProducts.length})', style: AppCss.mediumBold),
          const H(8),
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.neutralLight), borderRadius: AppCss.radius8),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: extractedProducts.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: AppColors.neutralLight),
              itemBuilder: (context, index) {
                final p = extractedProducts[index];
                final exists = FirestoreClient.produtos.data.any((e) => e.codigoFinanceiro == p['codigo']);
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_basket_outlined, size: 20, color: exists ? Colors.green : Colors.red),
                      const W(12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${p['codigo']} - ${p['descricao']}', style: AppCss.minimumBold.setSize(13).setColor(exists ? Colors.black : Colors.red)),
                            Text('Qtde: ${p['qtde']} KG | Unitário: R\$ ${p['unitario']} | Total Item: R\$ ${p['total']}', style: AppCss.minimumRegular.setSize(11)),
                          ],
                        ),
                      ),
                      if (!exists) 
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(color: Colors.red, borderRadius: AppCss.radius4),
                           child: const Text('PRODUTO NÃO CADASTRADO', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                         ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {Color? color, bool readOnly = false, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppCss.minimumBold.setSize(12)),
        const H(4),
        TextField(
          controller: ctrl,
          readOnly: readOnly,
          onChanged: onChanged,
          style: TextStyle(color: color, fontWeight: color != null ? FontWeight.bold : null),
          decoration: InputDecoration(
            isDense: true,
            fillColor: readOnly ? AppColors.neutralLight.withValues(alpha: 0.1) : Colors.white,
            filled: true,
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
          Expanded(
            child: AppTextButton.outlined(
              label: 'Cancelar',
              onPressed: () => Navigator.pop(context),
              isEnable: !isUploading,
            ),
          ),
          const W(12),
          if (currentStep == 1)
            Expanded(
              child: AppTextButton(
                label: isUploading ? 'Validando...' : 'Confirmar e Gerar Cartão',
                onPressed: _generateCard,
                isEnable: !isUploading,
              ),
            ),
        ],
      ),
    );
  }
}
