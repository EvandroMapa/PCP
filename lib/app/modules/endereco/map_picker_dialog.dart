import 'dart:async';
import 'dart:developer';

import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Abre um mapa onde o usuário clica para escolher a localização.
/// Retorna [MapPickerResult] com lat, lon e endereço reverso, ou null se cancelado.
Future<MapPickerResult?> abrirMapaPicker(
  BuildContext context, {
  LatLng? inicial,
}) {
  return showDialog<MapPickerResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MapPickerDialog(inicial: inicial),
  );
}

class MapPickerResult {
  final double lat;
  final double lon;
  final String logradouro;
  final String numero;
  final String bairro;
  final String cidade;
  final String estado;
  final String cep;

  const MapPickerResult({
    required this.lat,
    required this.lon,
    this.logradouro = '',
    this.numero = '',
    this.bairro = '',
    this.cidade = '',
    this.estado = '',
    this.cep = '',
  });
}

class MapPickerDialog extends StatefulWidget {
  final LatLng? inicial;
  const MapPickerDialog({this.inicial, super.key});

  @override
  State<MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<MapPickerDialog> {
  static const _apiKey = 'AIzaSyCU0z9swWm0LqdOkXIeoDuRJkBnqHuMvzw';

  final Completer<GoogleMapController> _ctrl = Completer();

  // Posição padrão: centro do Brasil
  static const _brasil = LatLng(-15.7942, -47.8822);

  late LatLng _marcador;
  bool _carregandoEndereco = false;
  String _enderecoPreview = 'Toque no mapa para escolher o local';

  @override
  void initState() {
    super.initState();
    _marcador = widget.inicial ?? _brasil;
    if (widget.inicial != null) {
      _buscarEnderecoReverso(widget.inicial!);
    }
  }

  Future<void> _buscarEnderecoReverso(LatLng ponto) async {
    setState(() => _carregandoEndereco = true);
    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${ponto.latitude},${ponto.longitude}&language=pt-BR&key=$_apiKey';
      final res = await Dio().get(url);
      final results = res.data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        setState(() {
          _enderecoPreview =
              results.first['formatted_address'] as String? ?? '';
        });
      }
    } catch (e) {
      log('[MapPicker] erro reverso: $e');
    } finally {
      if (mounted) setState(() => _carregandoEndereco = false);
    }
  }

  Future<MapPickerResult> _montarResultado() async {
    try {
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${_marcador.latitude},${_marcador.longitude}&language=pt-BR&key=$_apiKey';
      final res = await Dio().get(url);
      final results = res.data['results'] as List?;
      if (results == null || results.isEmpty) {
        return MapPickerResult(lat: _marcador.latitude, lon: _marcador.longitude);
      }

      final components = results.first['address_components'] as List? ?? [];
      String logradouro = '', numero = '', bairro = '', cidade = '', estado = '', cep = '';

      for (final c in components) {
        final types = List<String>.from(c['types'] as List);
        final long = c['long_name'] as String;
        final short = c['short_name'] as String;
        if (types.contains('route')) logradouro = long;
        if (types.contains('street_number')) numero = long;
        if (types.contains('sublocality') || types.contains('neighborhood')) bairro = long;
        if (types.contains('administrative_area_level_2')) cidade = long;
        if (types.contains('administrative_area_level_1')) estado = short;
        if (types.contains('postal_code')) cep = long.replaceAll('-', '');
      }

      return MapPickerResult(
        lat: _marcador.latitude,
        lon: _marcador.longitude,
        logradouro: logradouro,
        numero: numero,
        bairro: bairro,
        cidade: cidade,
        estado: estado,
        cep: cep,
      );
    } catch (e) {
      return MapPickerResult(lat: _marcador.latitude, lon: _marcador.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // ── Cabeçalho ──────────────────────────────────────────────
            Container(
              color: AppColors.primaryMain,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.map_outlined,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Escolher localização no mapa',
                      style:
                          AppCss.mediumBold.setColor(Colors.white).setSize(14),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── Mapa ───────────────────────────────────────────────────
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _marcador,
                      zoom: widget.inicial != null ? 15 : 5,
                    ),
                    onMapCreated: (c) => _ctrl.complete(c),
                    onTap: (ponto) {
                      setState(() => _marcador = ponto);
                      _buscarEnderecoReverso(ponto);
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('selecionado'),
                        position: _marcador,
                        draggable: true,
                        onDragEnd: (ponto) {
                          setState(() => _marcador = ponto);
                          _buscarEnderecoReverso(ponto);
                        },
                      ),
                    },
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  ),

                  // Hint central (some ao tocar)
                  if (_enderecoPreview ==
                      'Toque no mapa para escolher o local')
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '📍  Toque no mapa para marcar o local',
                          style: AppCss.mediumRegular
                              .setColor(Colors.white)
                              .setSize(13),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Preview do endereço + botão confirmar ──────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place,
                          size: 16, color: AppColors.primaryMain),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _carregandoEndereco
                            ? Row(
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Buscando endereço...',
                                      style: AppCss.smallRegular
                                          .setColor(Colors.grey)
                                          .setSize(12)),
                                ],
                              )
                            : Text(
                                _enderecoPreview,
                                style: AppCss.smallRegular
                                    .setSize(12)
                                    .setColor(Colors.grey[700]!),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${_marcador.latitude.toStringAsFixed(6)}  '
                    'Lon: ${_marcador.longitude.toStringAsFixed(6)}',
                    style: AppCss.minimumRegular
                        .setSize(11)
                        .setColor(Colors.grey[500]!),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _marcador == _brasil && widget.inicial == null
                          ? null
                          : () async {
                              final resultado = await _montarResultado();
                              if (context.mounted) {
                                Navigator.pop(context, resultado);
                              }
                            },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Confirmar localização'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryMain,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
