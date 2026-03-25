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
  DateTime deliveryDate = DateTime.now().add(const Duration(days: 7));
  ClienteModel? selectedCliente;
  PedidoTipo selectedTipo = PedidoTipo.cda;
  List<Map<String, dynamic>> extractedProducts = [];

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
      // TODO: Implement real PDF text extraction here
      // Placeholder: In a real scenario, we'd use a library or backend service.
      // For now, I'll simulate extracting text from the provided images.
      
      // Simulação: Texto que seria extraído do PDF
      String simulatedText = """
      Pedido : 25799
      Cliente:
      3544 - Gabriel Wagner Santos Teixeira
      109501 VERGALHAO 5,0 MM PA CD CDA 12.FAT2-CD KG 271,62 7,50 2.037,15
      109499 VERGALHAO 10,0 MM 3/8 PA CD CDA 12.FAT2-CD KG 672,77 6,30 4.238,45
      109531 VERGALHAO 12,5 MM 1/2 PA CD CDA 12.FAT2-CD KG 363,05 6,30 2.287,22
      """;

      final parsedData = PedidoPdfParser.parse(simulatedText);

      setState(() {
        financeiroCtrl.text = parsedData['pedidoFinanceiro'];
        // Tenta encontrar o cliente pelo código
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
        currentStep = 1; // Move to Conference Step
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
      // 1. Validar e Sincronizar Cliente
      if (selectedCliente != null) {
        final existing = FirestoreClient.clientes.getById(selectedCliente!.id);
        if (existing.id == 'NOTFOUND') {
          // Salva novo cliente no banco
          await AppSupabaseClient.clientes.add(selectedCliente!);
        }
      }

      // 2. Criar o PedidoModel
      final pedido = PedidoModel.empty().copyWith(
        localizador: localizadorCtrl.text,
        pedidoFinanceiro: financeiroCtrl.text,
        descricao: descricaoCtrl.text,
        deliveryAt: deliveryDate,
        cliente: selectedCliente ?? ClienteModel.empty(),
        tipo: selectedTipo,
        statusess: [PedidoStatusModel.create(PedidoStatus.aguardandoProducaoCDA)],
        steps: [PedidoStepModel.create(FirestoreClient.steps.data.first)],
      );

      // 3. Criar os PedidoProdutoModel
      final List<PedidoProdutoModel> produtos = [];
      for (final p in extractedProducts) {
        // Encontra o produto no banco pelo codigo financeiro
        final produtoBase = FirestoreClient.produtos.data.firstWhere(
          (e) => e.codigoFinanceiro == p['codigo'],
          orElse: () => ProdutoModel.empty().copyWith(nome: p['descricao']),
        );

        produtos.add(PedidoProdutoModel(
          id: HashService.get,
          pedidoId: pedido.id,
          clienteId: pedido.cliente.id,
          obraId: '', // Por enquanto
          produto: produtoBase,
          statusess: [PedidoProdutoStatusModel.empty()],
          qtde: p['qtde'],
          valorUnitario: p['unitario'],
          valorTotal: p['total'],
        ));
      }

      // 4. Persistir tudo no Supabase
      await AppSupabaseClient.pedidos.add(pedido);
      for (final p in produtos) {
        await AppSupabaseClient.pedidoProdutos.add(p);
      }

      if (mounted) {
        Navigator.pop(context);
        NotificationService.showPositive('Sucesso', 'Cartão de pedido gerado com sucesso!');
      }
    } catch (e) {
      NotificationService.showNegative('Erro', 'Falha ao gerar cartão: $e');
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppCss.radius12),
      child: Container(
        width: 700,
        height: 750,
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
            currentStep == 0 ? 'IMPORTAR PEDIDO (PDF)' : 'CONFERÊNCIA DOS DADOS',
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
                  Text('O sistema irá extrair os dados automaticamente', style: AppCss.minimumRegular),
                ],
              ),
            ),
          ),
          if (isUploading) ...[
            const H(24),
            const CircularProgressIndicator(),
            const H(8),
            const Text('Processando arquivo...'),
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
          _buildField('Obra / Local de Entrega', obraCtrl),
          const H(12),
          _buildField('Descrição / Observação', descricaoCtrl),
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
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_basket_outlined, size: 16, color: Colors.blue),
                      const W(8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${p['codigo']} - ${p['descricao']}', style: AppCss.minimumBold.setSize(12)),
                            Text('Qtde: ${p['qtde']} KG | Un: R\$ ${p['unitario']} | Total: R\$ ${p['total']}', style: AppCss.minimumRegular.setSize(10)),
                          ],
                        ),
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

  Widget _buildField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppCss.minimumBold.setSize(12)),
        const H(4),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            isDense: true,
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
                label: isUploading ? 'Gerando...' : 'Gerar Cartão',
                onPressed: _generateCard,
                isEnable: !isUploading,
              ),
            ),
        ],
      ),
    );
  }
}
