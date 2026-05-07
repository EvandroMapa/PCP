import 'dart:async';
import 'dart:developer';

import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/cliente/cliente_supabase_collection.dart';
import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const _googleApiKey = 'AIzaSyCU0z9swWm0LqdOkXIeoDuRJkBnqHuMvzw';

class MapaObrasWidget extends StatefulWidget {
  const MapaObrasWidget({super.key});

  @override
  State<MapaObrasWidget> createState() => _MapaObrasWidgetState();
}

class _MapaObrasWidgetState extends State<MapaObrasWidget> {
  final Completer<GoogleMapController> _controller = Completer();

  /// Todos os markers carregados
  List<_ObraInfo> _todasObras = [];

  /// Cidades selecionadas no filtro (vazio = todas)
  Set<String> _cidadesSelecionadas = {};

  bool _carregando = true;
  String _statusMsg = 'Carregando obras...';
  bool _filtroAberto = false;

  static const CameraPosition _posicaoInicial = CameraPosition(
    target: LatLng(-15.7942, -47.8822),
    zoom: 5,
  );

  /// Cidades disponíveis (extraídas dos markers)
  List<String> get _cidades {
    final set = <String>{};
    for (final o in _todasObras) {
      if (o.cidade.isNotEmpty) set.add(o.cidade);
    }
    final list = set.toList()..sort();
    return list;
  }

  /// Markers filtrados pela seleção de cidades
  Set<Marker> get _markersFiltrados {
    final obras = _cidadesSelecionadas.isEmpty
        ? _todasObras
        : _todasObras
            .where((o) => _cidadesSelecionadas.contains(o.cidade))
            .toList();

    return obras.map((info) {
      return Marker(
        markerId: MarkerId(info.obraId),
        position: LatLng(info.lat, info.lon),
        infoWindow: InfoWindow(
          title: info.descricao,
          snippet: '${info.cliente} · ${info.pedidos.length} pedido(s)',
          onTap: () => _showObraDetalhe(info),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    }).toSet();
  }

  @override
  void initState() {
    super.initState();
    _carregarMarkers();
  }

  Future<void> _carregarMarkers() async {
    final pedidosAtivos =
        FirestoreClient.pedidos.data.where((p) => !p.isArchived).toList();

    final Map<String, List<String>> obraParaPedidos = {};
    for (final pedido in pedidosAtivos) {
      final obraId = pedido.obra.id;
      if (obraId.isEmpty || obraId == 'NOTFOUND') continue;
      obraParaPedidos.putIfAbsent(obraId, () => []).add(pedido.localizador);
    }

    final List<_ObraInfo> obras = [];
    final List<_ObraParaGeocodificar> semCoordenadas = [];

    for (final cliente in FirestoreClient.clientes.data) {
      for (final obra in cliente.obras) {
        if (!obraParaPedidos.containsKey(obra.id)) continue;
        final endereco = obra.endereco;
        if (endereco == null) continue;

        if (endereco.lat != 0.0 || endereco.lon != 0.0) {
          obras.add(_ObraInfo(
            obraId: obra.id,
            descricao: obra.descricao,
            cliente: cliente.nome,
            lat: endereco.lat,
            lon: endereco.lon,
            cidade: endereco.localidade,
            localidade: '${endereco.localidade} - ${endereco.estado}',
            pedidos: obraParaPedidos[obra.id]!,
          ));
        } else {
          semCoordenadas.add(_ObraParaGeocodificar(
            obraId: obra.id,
            clienteId: cliente.id,
            clienteNome: cliente.nome,
            descricao: obra.descricao,
            endereco: endereco,
            pedidos: obraParaPedidos[obra.id]!,
          ));
        }
      }
    }

    if (semCoordenadas.isNotEmpty) {
      if (mounted) {
        setState(
            () => _statusMsg = 'Geocodificando ${semCoordenadas.length} obra(s)...');
      }
      for (final item in semCoordenadas) {
        final coords = await _geocodificar(item.endereco);
        if (coords != null) {
          final enderecoAtualizado =
              item.endereco.copyWith(lat: coords.$1, lon: coords.$2);
          await ClienteSupabaseCollection()
              .updateObraEndereco(item.obraId, enderecoAtualizado);

          obras.add(_ObraInfo(
            obraId: item.obraId,
            descricao: item.descricao,
            cliente: item.clienteNome,
            lat: coords.$1,
            lon: coords.$2,
            cidade: item.endereco.localidade,
            localidade:
                '${item.endereco.localidade} - ${item.endereco.estado}',
            pedidos: item.pedidos,
          ));
        }
      }
    }

    if (mounted) {
      setState(() {
        _todasObras = obras;
        _carregando = false;
      });
      final markers = _markersFiltrados;
      if (markers.isNotEmpty) _fitBounds(markers);
    }
  }

  Future<(double, double)?> _geocodificar(EnderecoModel e) async {
    try {
      final partes = [
        e.logradouro, e.numero, e.bairro, e.localidade, e.estado, e.cep, 'Brasil'
      ].where((p) => p.isNotEmpty).toList();
      if (partes.isEmpty) return null;

      final endereco = partes.join(', ');
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(endereco)}&key=$_googleApiKey';
      final response = await Dio().get(url);
      final results = response.data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final location = results.first['geometry']['location'];
      final lat = (location['lat'] as num).toDouble();
      final lon = (location['lng'] as num).toDouble();
      log('[Geocoding] $endereco → $lat, $lon');
      return (lat, lon);
    } catch (e) {
      log('[Geocoding] erro: $e');
      return null;
    }
  }

  /// Redimensiona a câmera para cobrir todos os [markers] visíveis.
  /// Usa postFrameCallback para garantir que o mapa já foi renderizado.
  void _fitBounds(Set<Marker> markers) {
    if (markers.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = await _controller.future;

      double minLat = markers.first.position.latitude;
      double maxLat = markers.first.position.latitude;
      double minLng = markers.first.position.longitude;
      double maxLng = markers.first.position.longitude;

      for (final m in markers) {
        if (m.position.latitude < minLat) minLat = m.position.latitude;
        if (m.position.latitude > maxLat) maxLat = m.position.latitude;
        if (m.position.longitude < minLng) minLng = m.position.longitude;
        if (m.position.longitude > maxLng) maxLng = m.position.longitude;
      }

      // Marker único: zoom fixo em 13
      if (markers.length == 1) {
        controller.animateCamera(CameraUpdate.newLatLngZoom(
          markers.first.position,
          13,
        ));
        return;
      }

      controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.3, minLng - 0.3),
          northeast: LatLng(maxLat + 0.3, maxLng + 0.3),
        ),
        60,
      ));
    });
  }

  void _toggleCidade(String cidade) {
    setState(() {
      if (_cidadesSelecionadas.contains(cidade)) {
        _cidadesSelecionadas.remove(cidade);
      } else {
        _cidadesSelecionadas.add(cidade);
      }
    });
    _fitBounds(_markersFiltrados);
  }

  void _showObraDetalhe(_ObraInfo info) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryMain,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(info.descricao,
                          style: AppCss.mediumBold
                              .setSize(16)
                              .setColor(Colors.white),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(info.cliente,
                      style: AppCss.minimumRegular
                          .setSize(13)
                          .setColor(Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 2),
                  Text(info.localidade,
                      style: AppCss.minimumRegular
                          .setSize(12)
                          .setColor(Colors.white.withValues(alpha: 0.7))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PEDIDOS ATIVOS (${info.pedidos.length})',
                      style: AppCss.minimumBold
                          .setSize(11)
                          .setColor(Colors.grey[500]!)),
                  const SizedBox(height: 8),
                  ...info.pedidos.map((loc) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: AppColors.primaryMain,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(loc, style: AppCss.mediumBold.setSize(13)),
                        ]),
                      )),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return Container(
        color: const Color(0xFFCBD5E1),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusMsg,
                style: AppCss.minimumRegular.setColor(Colors.grey[600]!)),
          ]),
        ),
      );
    }

    if (_todasObras.isEmpty) {
      return Container(
        color: const Color(0xFFCBD5E1),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_off_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Nenhuma obra com endereço cadastrado.',
                style: AppCss.mediumRegular.setColor(Colors.grey[500]!)),
            const SizedBox(height: 8),
            Text('Cadastre o endereço nas obras dos pedidos ativos.',
                style: AppCss.minimumRegular.setColor(Colors.grey[400]!)),
          ]),
        ),
      );
    }

    final markers = _markersFiltrados;

    return Stack(
      children: [
        // ── Mapa ──────────────────────────────────────────────────────────
        GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: _posicaoInicial,
          markers: markers,
          onMapCreated: (controller) {
            _controller.complete(controller);
            _fitBounds(markers);
          },
          zoomControlsEnabled: true,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
        ),

        // ── Painel de filtro por cidade ────────────────────────────────────
        Positioned(
          top: 16,
          left: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Botão toggle do filtro
              GestureDetector(
                onTap: () => setState(() => _filtroAberto = !_filtroAberto),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _cidadesSelecionadas.isEmpty
                        ? Colors.white
                        : AppColors.primaryMain,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.filter_list,
                        size: 16,
                        color: _cidadesSelecionadas.isEmpty
                            ? AppColors.primaryMain
                            : Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      _cidadesSelecionadas.isEmpty
                          ? 'Todas as cidades'
                          : _cidadesSelecionadas.length == 1
                              ? _cidadesSelecionadas.first
                              : '${_cidadesSelecionadas.length} cidades',
                      style: AppCss.mediumBold.setSize(13).setColor(
                            _cidadesSelecionadas.isEmpty
                                ? AppColors.primaryMain
                                : Colors.white,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _filtroAberto
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: _cidadesSelecionadas.isEmpty
                          ? AppColors.primaryMain
                          : Colors.white,
                    ),
                  ]),
                ),
              ),

              // Painel de seleção de cidades
              if (_filtroAberto) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxWidth: 260, maxHeight: 320),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "Todas"
                      InkWell(
                        onTap: () {
                          setState(() {
                            _cidadesSelecionadas.clear();
                            _filtroAberto = false;
                          });
                          // Pequeno delay para o setState processar antes do fitBounds
                          Future.microtask(() => _fitBounds(_markersFiltrados));
                        },
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _cidadesSelecionadas.isEmpty
                                ? AppColors.primaryMain.withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            border: Border(
                                bottom: BorderSide(
                                    color: Colors.grey[200]!, width: 1)),
                          ),
                          child: Row(children: [
                            Icon(Icons.public,
                                size: 16,
                                color: _cidadesSelecionadas.isEmpty
                                    ? AppColors.primaryMain
                                    : Colors.grey[500]),
                            const SizedBox(width: 10),
                            Text('Todas as cidades',
                                style: AppCss.mediumBold.setSize(13).setColor(
                                      _cidadesSelecionadas.isEmpty
                                          ? AppColors.primaryMain
                                          : Colors.grey[700]!,
                                    )),
                            const Spacer(),
                            if (_cidadesSelecionadas.isEmpty)
                              Icon(Icons.check,
                                  size: 16, color: AppColors.primaryMain),
                          ]),
                        ),
                      ),

                      // Lista de cidades
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _cidades.length,
                          itemBuilder: (_, i) {
                            final cidade = _cidades[i];
                            final sel = _cidadesSelecionadas.contains(cidade);
                            final qtd = _todasObras
                                .where((o) => o.cidade == cidade)
                                .length;
                            return InkWell(
                              onTap: () => _toggleCidade(cidade),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 11),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppColors.primaryMain
                                          .withValues(alpha: 0.07)
                                      : Colors.transparent,
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey[100]!,
                                          width: 1)),
                                ),
                                child: Row(children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? AppColors.primaryMain
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: sel
                                            ? AppColors.primaryMain
                                            : Colors.grey[400]!,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: sel
                                        ? const Icon(Icons.check,
                                            size: 12, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(cidade,
                                        style:
                                            AppCss.mediumBold.setSize(13).setColor(
                                                  sel
                                                      ? AppColors.primaryMain
                                                      : Colors.grey[800]!,
                                                )),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: sel
                                          ? AppColors.primaryMain
                                              .withValues(alpha: 0.12)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text('$qtd',
                                        style: AppCss.minimumBold
                                            .setSize(11)
                                            .setColor(sel
                                                ? AppColors.primaryMain
                                                : Colors.grey[500]!)),
                                  ),
                                ]),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Badge total de obras visíveis ─────────────────────────────────
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.location_on, size: 16, color: AppColors.primaryMain),
              const SizedBox(width: 6),
              Text(
                '${markers.length} obra${markers.length != 1 ? 's' : ''}',
                style: AppCss.mediumBold
                    .setSize(13)
                    .setColor(AppColors.primaryMain),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── Modelos internos ──────────────────────────────────────────────────────────

class _ObraInfo {
  final String obraId;
  final String descricao;
  final String cliente;
  final double lat;
  final double lon;
  final String cidade;
  final String localidade;
  final List<String> pedidos;

  _ObraInfo({
    required this.obraId,
    required this.descricao,
    required this.cliente,
    required this.lat,
    required this.lon,
    required this.cidade,
    required this.localidade,
    required this.pedidos,
  });
}

class _ObraParaGeocodificar {
  final String obraId;
  final String clienteId;
  final String clienteNome;
  final String descricao;
  final EnderecoModel endereco;
  final List<String> pedidos;

  _ObraParaGeocodificar({
    required this.obraId,
    required this.clienteId,
    required this.clienteNome,
    required this.descricao,
    required this.endereco,
    required this.pedidos,
  });
}
