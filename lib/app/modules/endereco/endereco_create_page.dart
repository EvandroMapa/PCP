import 'package:aco_plus/app/core/components/app_field.dart';
import 'package:aco_plus/app/core/components/app_scaffold.dart';
import 'package:aco_plus/app/core/components/done_button.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/endereco/endereco_controller.dart';
import 'package:aco_plus/app/modules/endereco/map_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EnderecoCreatePage extends StatefulWidget {
  final EnderecoModel? endereco;
  const EnderecoCreatePage({this.endereco, super.key});

  @override
  State<EnderecoCreatePage> createState() => _EnderecoCreatePageState();
}

class _EnderecoCreatePageState extends State<EnderecoCreatePage> {
  @override
  void initState() {
    enderecoCtrl.onInitEndereco(widget.endereco);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      resizeAvoid: true,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () async {
            if (!enderecoCtrl.houveMudanca) {
              pop(context);
              return;
            }
            if (await showConfirmDialog(
              'Deseja realmente sair?',
              'Os dados do endereço serão perdidos.',
            )) {
              pop(context);
            }
          },
          icon: Icon(Icons.arrow_back, color: AppColors.white),
        ),
        title: Text(
          '${enderecoCtrl.form.isEdit ? 'Editar' : 'Adicionar'} Endereco',
          style: AppCss.largeBold.setColor(AppColors.white),
        ),
        actions: [
          IconLoadingButton(() async => await enderecoCtrl.onConfirm(context)),
        ],
        backgroundColor: AppColors.primaryMain,
      ),
      body: StreamOut(
        stream: enderecoCtrl.enderecoCreateStream.listen,
        builder: (_, form) => body(form),
      ),
    );
  }

  Widget body(EnderecoCreateModel form) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppField(
          label: 'CEP',
          type: TextInputType.number,
          controller: form.cep,
          hint: form.cep.mask!,
          onChanged: (value) {
            if (value.length == 9) {
              enderecoCtrl.onSearchCEP(value);
            }
            enderecoCtrl.enderecoCreateStream.update();
          },
        ),
        const H(16),
        AppField(
          label: 'Logradouro',
          controller: form.logradouro,
          onChanged: (_) => enderecoCtrl.enderecoCreateStream.update(),
        ),
        const H(16),
        AppField(
          label: 'Bairro',
          controller: form.bairro,
          onChanged: (_) => enderecoCtrl.enderecoCreateStream.update(),
        ),
        const H(16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: AppField(
                label: 'Localidade',
                controller: form.localidade,
                onChanged: (_) => enderecoCtrl.enderecoCreateStream.update(),
              ),
            ),
            const W(8),
            Expanded(
              flex: 2,
              child: AppField(
                label: 'UF',
                controller: form.estado,
                onChanged: (_) => enderecoCtrl.enderecoCreateStream.update(),
              ),
            ),
          ],
        ),
        const H(16),
        Row(
          children: [
            Expanded(
              child: AppField(
                label: 'Número',
                type: TextInputType.number,
                controller: form.numero,
                onChanged: (_) => enderecoCtrl.enderecoCreateStream.update(),
              ),
            ),
            const W(8),
            Expanded(
              flex: 2,
              child: AppField(
                label: 'Complemento',
                required: false,
                controller: form.complemento,
                onChanged: (_) => enderecoCtrl.enderecoCreateStream.update(),
              ),
            ),
          ],
        ),
        const H(16),
        // ── Lat / Lon + botão de mapa ────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppField(
                label: 'Latitude',
                controller: form.lat,
                type: TextInputType.number,
                onChanged: (_) => enderecoCtrl.enderecoCreateStream.update(),
              ),
            ),
            const W(8),
            Expanded(
              child: AppField(
                label: 'Longitude',
                type: TextInputType.number,
                controller: form.lon,
                onChanged: (_) => enderecoCtrl.enderecoCreateStream.update(),
              ),
            ),
            const W(8),
            // Botão abrir mapa
            Tooltip(
              message: 'Escolher no mapa',
              child: InkWell(
                onTap: () => _abrirMapa(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryMain.withValues(alpha: 0.1),
                    border: Border.all(
                        color: AppColors.primaryMain.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.map_outlined,
                      color: AppColors.primaryMain, size: 22),
                ),
              ),
            ),
          ],
        ),
        const H(16),
      ],
    );
  }

  Future<void> _abrirMapa() async {
    final lat = double.tryParse(enderecoCtrl.form.lat.text);
    final lon = double.tryParse(enderecoCtrl.form.lon.text);
    final inicial = (lat != null && lon != null)
        ? LatLng(lat, lon)
        : null;

    final resultado = await abrirMapaPicker(context, inicial: inicial);
    if (resultado == null) return;

    // Limpa todos os campos antes de preencher — o que o Google não trouxer fica vazio
    enderecoCtrl.form.cep.text = '';
    enderecoCtrl.form.logradouro.text = '';
    enderecoCtrl.form.numero.text = '';
    enderecoCtrl.form.bairro.text = '';
    enderecoCtrl.form.localidade.text = '';
    enderecoCtrl.form.estado.text = '';

    // Preenche apenas o que veio do reverse geocoding
    enderecoCtrl.form.lat.text = resultado.lat.toString();
    enderecoCtrl.form.lon.text = resultado.lon.toString();
    enderecoCtrl.form.cep.text = resultado.cep;
    enderecoCtrl.form.logradouro.text = resultado.logradouro;
    enderecoCtrl.form.numero.text = resultado.numero;
    enderecoCtrl.form.bairro.text = resultado.bairro;
    enderecoCtrl.form.localidade.text = resultado.cidade;
    enderecoCtrl.form.estado.text = resultado.estado;

    enderecoCtrl.enderecoCreateStream.update();
  }
}
