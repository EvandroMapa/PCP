import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/patio/patio_controller.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

class PatioParquePage extends StatefulWidget {
  const PatioParquePage({super.key});

  @override
  State<PatioParquePage> createState() => _PatioParquePageState();
}

class _PatioParquePageState extends State<PatioParquePage> {
  GoogleMapController? _mapController;
  PatioModel? _patioSelecionado;
  
  // Ponto inicial dinâmico
  CameraPosition get _pontoInicial {
    final lat = PreferencesService.empresaLat.value ?? -23.5505;
    final lng = PreferencesService.empresaLng.value ?? -46.6333;
    return CameraPosition(
      target: LatLng(lat, lng),
      zoom: 18, // Mais zoom por padrão para ver a planta da empresa
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<PatioModel>>(
      stream: FirestoreClient.patios.dataStream.listen,
      builder: (_, patios) {
        if (patios.isEmpty) {
          return const Center(child: Text('Nenhum pátio cadastrado.'));
        }

        return Row(
          children: [
            // Lista lateral de pátios
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Pátios no Parque',
                      style: AppCss.mediumBold.setColor(AppColors.primaryMain),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: patios.length,
                      itemBuilder: (_, i) {
                        final p = patios[i];
                        final sel = _patioSelecionado?.id == p.id;
                        final temLoc = p.latitude != null && p.longitude != null;

                        return ListTile(
                          selected: sel,
                          selectedTileColor: AppColors.primaryMain.withValues(alpha: 0.05),
                          leading: Icon(
                            temLoc ? Icons.location_on : Icons.location_off_outlined,
                            color: temLoc ? Colors.red : Colors.grey[400],
                            size: 18,
                          ),
                          title: Text(p.nome, style: AppCss.smallBold),
                          subtitle: Text(
                            temLoc ? 'Localizado' : 'Não localizado',
                            style: AppCss.minimumRegular,
                          ),
                          trailing: temLoc
                              ? Tooltip(
                                  message: 'Limpar localização',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _limparLocalizacao(p),
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.location_disabled, size: 16, color: Colors.red),
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () {
                            setState(() => _patioSelecionado = p);
                            if (temLoc) {
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  LatLng(p.latitude!, p.longitude!),
                                  18,
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Mapa
            Expanded(
              child: Stack(
                children: [
                  MouseRegion(
                    cursor: _patioSelecionado != null &&
                            _patioSelecionado!.latitude == null
                        ? SystemMouseCursors.precise
                        : SystemMouseCursors.basic,
                    child: GoogleMap(
                      initialCameraPosition: _pontoInicial,
                      mapType: MapType.hybrid, // Satélite + Ruas
                      onMapCreated: (controller) => _mapController = controller,
                      markers: _buildMarkers(patios),
                      onTap: (pos) => _onMapTap(pos),
                      myLocationButtonEnabled: true,
                      myLocationEnabled: true,
                    ),
                  ),
                  
                  // Dica visual se estiver selecionando local
                  if (_patioSelecionado != null && _patioSelecionado!.latitude == null)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: PointerInterceptor(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.touch_app, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Clique no mapa para definir a localização do pátio "${_patioSelecionado!.nome}"',
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                                onPressed: () => setState(() => _patioSelecionado = null),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Set<Marker> _buildMarkers(List<PatioModel> patios) {
    return patios
        .where((p) => p.latitude != null && p.longitude != null)
        .map((p) {
      return Marker(
        markerId: MarkerId(p.id),
        position: LatLng(p.latitude!, p.longitude!),
        infoWindow: InfoWindow(
          title: p.nome,
          snippet: '${p.comprimento}m x ${p.largura}m',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }).toSet();
  }

  Future<void> _onMapTap(LatLng pos) async {
    if (_patioSelecionado == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: PointerInterceptor(
          child: AlertDialog(
            title: const Text('Definir Localização'),
            content: Text('Deseja definir este ponto como a localização do pátio "${_patioSelecionado!.nome}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMain),
                child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmar == true) {
      final updated = _patioSelecionado!.copyWith(
        latitude: () => pos.latitude,
        longitude: () => pos.longitude,
      );
      await FirestoreClient.patios.update(updated);
      setState(() => _patioSelecionado = null);
    }
  }

  Future<void> _limparLocalizacao(PatioModel patio) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Localização'),
        content: Text('Deseja remover a localização do pátio "${patio.nome}" do mapa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Limpar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final updated = patio.copyWith(
        latitude: () => null,
        longitude: () => null,
      );
      await FirestoreClient.patios.update(updated);
      setState(() {
        if (_patioSelecionado?.id == patio.id) {
          _patioSelecionado = null;
        }
      });
    }
  }
}
