import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';

enum _ModoParque { geo, croqui }

class PatioParquePage extends StatefulWidget {
  const PatioParquePage({super.key});
  @override
  State<PatioParquePage> createState() => _PatioParquePageState();
}

class _PatioParquePageState extends State<PatioParquePage> {
  _ModoParque _modo = _ModoParque.croqui;
  GoogleMapController? _mapController;
  PatioModel? _patioSelecionado;
  bool _posicionando = false;

  // Drag em tempo real
  String? _draggingId;
  Offset _dragOffset = Offset.zero;
  // Posição otimista local (patioId -> (x, y)) para evitar flash ao soltar
  final Map<String, (int, int)> _posicaoLocal = {};

  final _compCtrl = TextEditingController();
  final _largCtrl = TextEditingController();

  CameraPosition get _pontoInicial {
    final lat = PreferencesService.empresaLat.value ?? -23.5505;
    final lng = PreferencesService.empresaLng.value ?? -46.6333;
    return CameraPosition(target: LatLng(lat, lng), zoom: 18);
  }

  @override
  void initState() {
    super.initState();
    final c = PreferencesService.parqueComprimento.value;
    final l = PreferencesService.parqueLargura.value;
    if (c > 0) _compCtrl.text = c.toString();
    if (l > 0) _largCtrl.text = l.toString();
  }

  @override
  void dispose() {
    _compCtrl.dispose();
    _largCtrl.dispose();
    super.dispose();
  }

  static const _cores = [
    Color(0xFF3B82F6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444),
    Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFF97316), Color(0xFFEC4899),
  ];
  Color _corDoPatio(int i) => _cores[i % _cores.length];

  @override
  Widget build(BuildContext context) {
    return StreamOut<List<PatioModel>>(
      stream: FirestoreClient.patios.dataStream.listen,
      builder: (_, patios) {
        if (patios.isEmpty) return const Center(child: Text('Nenhum pátio cadastrado.'));
        return Row(children: [
          _buildSidebar(patios),
          Expanded(child: _modo == _ModoParque.geo ? _buildMapaGeo(patios) : _buildGridCroqui(patios)),
        ]);
      },
    );
  }

  // ══════════ SIDEBAR ══════════
  Widget _buildSidebar(List<PatioModel> patios) {
    return Container(
      width: 260,
      decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: Colors.grey[200]!))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Pátios', style: AppCss.mediumBold.setColor(AppColors.primaryMain)),
        ),
        // Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(3),
            child: Row(children: [
              _toggle('Croqui', Icons.grid_on_rounded, _ModoParque.croqui),
              const SizedBox(width: 4),
              _toggle('Geo', Icons.map_outlined, _ModoParque.geo),
            ]),
          ),
        ),
        if (_modo == _ModoParque.croqui) ...[const SizedBox(height: 12), _buildCroquiConfig(patios)],
        const SizedBox(height: 8),
        Divider(height: 1, color: Colors.grey[200]),
        Expanded(child: _buildListaPatios(patios)),
      ]),
    );
  }

  Widget _toggle(String label, IconData icon, _ModoParque modo) {
    final sel = _modo == modo;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _modo = modo; _posicionando = false; _patioSelecionado = null; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: sel ? AppColors.primaryMain : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: sel ? Colors.white : Colors.grey[500]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? Colors.white : Colors.grey[600])),
          ]),
        ),
      ),
    );
  }

  // ══════════ CONFIG CROQUI ══════════
  Widget _buildCroquiConfig(List<PatioModel> patios) {
    final temAlocado = patios.any((p) => p.parqueX != null && p.parqueY != null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tamanho do Parque', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[700])),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _dimInput(_compCtrl, 'Comp. (m)', Icons.straighten, enabled: !temAlocado)),
            const SizedBox(width: 8),
            Expanded(child: _dimInput(_largCtrl, 'Larg. (m)', Icons.height, enabled: !temAlocado)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: temAlocado ? () {
                showDialog(context: context, builder: (ctx) => AlertDialog(
                  icon: Icon(Icons.info_outline, size: 40, color: Colors.orange[700]),
                  title: const Text('Parque bloqueado', textAlign: TextAlign.center),
                  content: const Text('Remova todos os pátios do croqui antes de alterar o tamanho.', textAlign: TextAlign.center),
                  actionsAlignment: MainAxisAlignment.center,
                  actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMain, foregroundColor: Colors.white), child: const Text('Entendi'))],
                ));
              } : () {
                final c = int.tryParse(_compCtrl.text), l = int.tryParse(_largCtrl.text);
                if (c != null && c > 0 && l != null && l > 0) {
                  PreferencesService.parqueComprimento.add(c);
                  PreferencesService.parqueLargura.add(l);
                  setState(() {});
                }
              },
              icon: Icon(temAlocado ? Icons.lock_outline : Icons.save_outlined, size: 16),
              label: Text(temAlocado ? 'Bloqueado' : 'Salvar', style: const TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: temAlocado ? Colors.grey[400] : AppColors.primaryMain,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dimInput(TextEditingController ctrl, String label, IconData icon, {bool enabled = true}) {
    return TextFormField(
      controller: ctrl, keyboardType: TextInputType.number, enabled: enabled,
      style: TextStyle(fontSize: 13, color: enabled ? null : Colors.grey[500]),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(fontSize: 11), prefixIcon: Icon(icon, size: 16), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: !enabled, fillColor: const Color(0xFFEEEEEE)),
    );
  }

  // ══════════ LISTA DE PÁTIOS ══════════
  Widget _buildListaPatios(List<PatioModel> patios) {
    return ListView.builder(
      itemCount: patios.length,
      itemBuilder: (_, i) {
        final p = patios[i];
        final sel = _patioSelecionado?.id == p.id;

        if (_modo == _ModoParque.geo) {
          final temLoc = p.latitude != null && p.longitude != null;
          return ListTile(
            selected: sel, selectedTileColor: AppColors.primaryMain.withValues(alpha: 0.05),
            leading: Icon(temLoc ? Icons.location_on : Icons.location_off_outlined, color: temLoc ? Colors.red : Colors.grey[400], size: 18),
            title: Text(p.nome, style: AppCss.smallBold),
            subtitle: Text('${p.comprimento}m × ${p.largura}m\n${temLoc ? 'Localizado' : 'Não localizado'}', style: AppCss.minimumRegular),
            isThreeLine: true,
            trailing: temLoc ? _botaoLimparGeo(p) : null,
            onTap: () {
              setState(() => _patioSelecionado = p);
              if (temLoc) _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(p.latitude!, p.longitude!), 18));
            },
          );
        }

        // Croqui
        final posicionado = p.parqueX != null && p.parqueY != null;
        return ListTile(
          selected: sel, selectedTileColor: AppColors.primaryMain.withValues(alpha: 0.05),
          leading: Container(width: 16, height: 16, decoration: BoxDecoration(color: _corDoPatio(i), borderRadius: BorderRadius.circular(4))),
          title: Text(p.nome, style: AppCss.smallBold),
          subtitle: Text('${p.comprimento}m × ${p.largura}m\n${posicionado ? 'Posicionado' : 'Não posicionado'}', style: AppCss.minimumRegular),
          isThreeLine: true,
          trailing: posicionado
              ? Tooltip(
                  message: 'Remover do croqui',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _removerDoCroqui(p),
                    child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close, size: 14, color: Colors.red)),
                  ),
                )
              : null,
          onTap: () {
            setState(() { _patioSelecionado = p; _posicionando = true; });
          },
        );
      },
    );
  }

  Widget _botaoLimparGeo(PatioModel p) {
    return Tooltip(
      message: 'Limpar localização',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _limparLocalizacao(p),
        child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.location_disabled, size: 16, color: Colors.red)),
      ),
    );
  }

  // ══════════ GRID CROQUI ══════════
  Widget _buildGridCroqui(List<PatioModel> patios) {
    final comp = PreferencesService.parqueComprimento.value;
    final larg = PreferencesService.parqueLargura.value;

    if (comp <= 0 || larg <= 0) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.grid_on_rounded, size: 60, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('Defina o tamanho do parque no painel lateral', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
      ]));
    }

    return LayoutBuilder(builder: (context, constraints) {
      const rulerSize = 20.0;
      final maxW = constraints.maxWidth - 32 - rulerSize;
      final maxH = constraints.maxHeight - 32 - rulerSize;
      final cellSize = (maxW / comp) < (maxH / larg) ? maxW / comp : maxH / larg;
      final totalW = cellSize * comp;
      final totalH = cellSize * larg;

      final rulerFontSize = (cellSize * 0.3).clamp(4.0, 10.0);
      final rulerStyle = TextStyle(fontSize: rulerFontSize, color: Colors.grey[500], fontWeight: FontWeight.w600);

      return Stack(children: [
        InteractiveViewer(
          minScale: 0.3,
          maxScale: 5.0,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(100),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Régua horizontal (topo)
            SizedBox(
              width: rulerSize + totalW,
              height: rulerSize,
              child: Row(children: [
                SizedBox(width: rulerSize),
                ...List.generate(comp, (i) => SizedBox(
                  width: cellSize,
                  child: Center(child: Text('${i + 1}', style: rulerStyle)),
                )),
              ]),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              // Régua vertical (esquerda)
              SizedBox(
                width: rulerSize,
                height: totalH,
                child: Column(children: List.generate(larg, (i) => SizedBox(
                  height: cellSize,
                  child: Center(child: Text('${i + 1}', style: rulerStyle)),
                ))),
              ),
              // Grid
              MouseRegion(
                cursor: _posicionando ? SystemMouseCursors.precise : SystemMouseCursors.basic,
                child: GestureDetector(
                  onTapDown: _posicionando ? (d) => _onGridTap(d, cellSize, comp, larg, patios) : null,
                  child: Container(
                    width: totalW, height: totalH,
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCBD5E1))),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: CustomPaint(
                        size: Size(totalW, totalH),
                    painter: _CroquiGridPainter(comprimento: comp, largura: larg, cellSize: cellSize),
                    child: Stack(
                      children: patios.asMap().entries.where((e) {
                        final p = e.value;
                        final loc = _posicaoLocal[p.id];
                        final px = loc?.$1 ?? p.parqueX;
                        final py = loc?.$2 ?? p.parqueY;
                        return px != null && py != null;
                      }).map((entry) {
                        final idx = entry.key;
                        final p = entry.value;
                        // Usa posição otimista se existir, senão do modelo
                        final loc = _posicaoLocal[p.id];
                        final px = loc?.$1 ?? p.parqueX!;
                        final py = loc?.$2 ?? p.parqueY!;
                        // Limpa posição otimista se modelo já está atualizado
                        if (loc != null && p.parqueX == loc.$1 && p.parqueY == loc.$2) {
                          _posicaoLocal.remove(p.id);
                        }
                        final sel = _patioSelecionado?.id == p.id;
                        final cor = _corDoPatio(idx);
                        final isDragging = _draggingId == p.id;
                        final left = isDragging ? px * cellSize + _dragOffset.dx : px * cellSize;
                        final top = isDragging ? py * cellSize + _dragOffset.dy : py * cellSize;
                        return Positioned(
                          left: left, top: top,
                          width: p.comprimento * cellSize, height: p.largura * cellSize,
                          child: GestureDetector(
                            onPanStart: (_) => setState(() { _draggingId = p.id; _dragOffset = Offset.zero; _posicionando = false; }),
                            onPanUpdate: (d) => setState(() => _dragOffset += d.delta),
                            onPanEnd: (_) => _onDragEnd(p, cellSize, comp, larg, patios),
                            onTap: () => setState(() { _patioSelecionado = p; _posicionando = true; }),
                            child: MouseRegion(
                              cursor: isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
                              child: Tooltip(
                                message: '${p.nome} (${p.comprimento}m × ${p.largura}m)',
                                child: Container(
                                  margin: const EdgeInsets.all(1),
                                  decoration: BoxDecoration(
                                    color: isDragging ? cor.withValues(alpha: 0.45) : sel ? cor.withValues(alpha: 0.35) : cor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: isDragging || sel ? cor : cor.withValues(alpha: 0.5), width: isDragging ? 3 : sel ? 2.5 : 1),
                                    boxShadow: isDragging ? [BoxShadow(color: cor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(2, 2))] : null,
                                  ),
                                  child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Text(p.nome, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cor.withValues(alpha: 0.8))),
                                  ))),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
            ]),  // fecha Row (régua + grid)
          ]),   // fecha Column
          ),    // fecha Padding
        ),      // fecha InteractiveViewer
        // Banner de instrução
        if (_posicionando && _patioSelecionado != null)
          Positioned(top: 16, left: 16, right: 16, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.touch_app, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Clique no grid para posicionar o pátio "${_patioSelecionado!.nome}"', style: const TextStyle(color: Colors.white, fontSize: 13))),
              IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: () => setState(() { _posicionando = false; _patioSelecionado = null; })),
            ]),
          )),
      ]);
    });
  }

  // ══════════ AÇÕES CROQUI ══════════
  void _onGridTap(TapDownDetails d, double cellSize, int comp, int larg, List<PatioModel> patios) {
    if (_patioSelecionado == null || !_posicionando) return;
    final x = (d.localPosition.dx / cellSize).floor();
    final y = (d.localPosition.dy / cellSize).floor();
    final p = _patioSelecionado!;

    if (x + p.comprimento > comp || y + p.largura > larg) {
      NotificationService.showNegative('Não cabe', 'O pátio ultrapassa os limites do parque.', position: NotificationPosition.bottom);
      return;
    }
    if (_temSobreposicao(p.id, x, y, p.comprimento, p.largura, patios)) {
      NotificationService.showNegative('Sobreposição', 'Já existe um pátio nessa posição.', position: NotificationPosition.bottom);
      return;
    }

    final updated = p.copyWith(parqueX: () => x, parqueY: () => y);
    FirestoreClient.patios.update(updated);
    setState(() { _posicionando = false; _patioSelecionado = null; });
  }
  void _onDragEnd(PatioModel p, double cellSize, int comp, int larg, List<PatioModel> patios) {
    final px = _posicaoLocal[p.id]?.$1 ?? p.parqueX!;
    final py = _posicaoLocal[p.id]?.$2 ?? p.parqueY!;
    final newX = ((px * cellSize + _dragOffset.dx) / cellSize).round().clamp(0, comp - p.comprimento);
    final newY = ((py * cellSize + _dragOffset.dy) / cellSize).round().clamp(0, larg - p.largura);

    if (newX == px && newY == py) {
      setState(() { _draggingId = null; _dragOffset = Offset.zero; });
      return;
    }

    if (_temSobreposicao(p.id, newX, newY, p.comprimento, p.largura, patios)) {
      setState(() { _draggingId = null; _dragOffset = Offset.zero; });
      NotificationService.showNegative('Sobreposição', 'Já existe um pátio nessa posição.', position: NotificationPosition.bottom);
      return;
    }

    // Posição otimista: renderiza no destino imediatamente
    _posicaoLocal[p.id] = (newX, newY);
    setState(() { _draggingId = null; _dragOffset = Offset.zero; });

    final updated = p.copyWith(parqueX: () => newX, parqueY: () => newY);
    FirestoreClient.patios.update(updated);
  }

  bool _temSobreposicao(String ignoreId, int x, int y, int w, int h, List<PatioModel> patios) {
    for (final o in patios) {
      if (o.id == ignoreId || o.parqueX == null || o.parqueY == null) continue;
      final overlapX = x < o.parqueX! + o.comprimento && x + w > o.parqueX!;
      final overlapY = y < o.parqueY! + o.largura && y + h > o.parqueY!;
      if (overlapX && overlapY) return true;
    }
    return false;
  }

  Future<void> _removerDoCroqui(PatioModel p) async {
    final updated = p.copyWith(parqueX: () => null, parqueY: () => null);
    await FirestoreClient.patios.update(updated);
    setState(() { if (_patioSelecionado?.id == p.id) _patioSelecionado = null; });
  }

  // ══════════ MAPA GEO ══════════
  Widget _buildMapaGeo(List<PatioModel> patios) {
    return Stack(children: [
      MouseRegion(
        cursor: _patioSelecionado != null && _patioSelecionado!.latitude == null ? SystemMouseCursors.precise : SystemMouseCursors.basic,
        child: GoogleMap(
          initialCameraPosition: _pontoInicial, mapType: MapType.hybrid,
          onMapCreated: (c) { _mapController = c; _fitMarkers(patios); },
          markers: _buildMarkers(patios), onTap: (pos) => _onMapTap(pos),
          myLocationButtonEnabled: true, myLocationEnabled: true,
        ),
      ),
      if (_patioSelecionado != null && _patioSelecionado!.latitude == null)
        Positioned(top: 16, left: 16, right: 16, child: PointerInterceptor(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.touch_app, color: Colors.white, size: 20), const SizedBox(width: 12),
            Expanded(child: Text('Clique no mapa para definir a localização do pátio "${_patioSelecionado!.nome}"', style: const TextStyle(color: Colors.white, fontSize: 13))),
            IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: () => setState(() => _patioSelecionado = null)),
          ]),
        ))),
    ]);
  }

  void _fitMarkers(List<PatioModel> patios) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_mapController == null) return;
      final loc = patios.where((p) => p.latitude != null && p.longitude != null).toList();
      if (loc.isEmpty) return;
      if (loc.length == 1) { _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(loc.first.latitude!, loc.first.longitude!), 20)); return; }
      double minLat = loc.first.latitude!, maxLat = minLat, minLng = loc.first.longitude!, maxLng = minLng;
      for (final p in loc) { if (p.latitude! < minLat) minLat = p.latitude!; if (p.latitude! > maxLat) maxLat = p.latitude!; if (p.longitude! < minLng) minLng = p.longitude!; if (p.longitude! > maxLng) maxLng = p.longitude!; }
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)), 60));
    });
  }

  Set<Marker> _buildMarkers(List<PatioModel> patios) {
    return patios.where((p) => p.latitude != null && p.longitude != null).map((p) => Marker(
      markerId: MarkerId(p.id), position: LatLng(p.latitude!, p.longitude!),
      infoWindow: InfoWindow(title: p.nome, snippet: '${p.comprimento}m x ${p.largura}m'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    )).toSet();
  }

  Future<void> _onMapTap(LatLng pos) async {
    if (_patioSelecionado == null) return;
    final ok = await showDialog<bool>(context: context, barrierDismissible: false,
      builder: (ctx) => MouseRegion(cursor: SystemMouseCursors.basic, child: PointerInterceptor(child: AlertDialog(
        title: const Text('Definir Localização'),
        content: Text('Deseja definir este ponto como a localização do pátio "${_patioSelecionado!.nome}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMain), child: const Text('Confirmar', style: TextStyle(color: Colors.white))),
        ],
      ))));
    if (ok == true) {
      await FirestoreClient.patios.update(_patioSelecionado!.copyWith(latitude: () => pos.latitude, longitude: () => pos.longitude));
      setState(() => _patioSelecionado = null);
    }
  }

  Future<void> _limparLocalizacao(PatioModel p) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Limpar Localização'), content: Text('Remover localização do pátio "${p.nome}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Limpar', style: TextStyle(color: Colors.white))),
      ],
    ));
    if (ok == true) {
      await FirestoreClient.patios.update(p.copyWith(latitude: () => null, longitude: () => null));
      setState(() { if (_patioSelecionado?.id == p.id) _patioSelecionado = null; });
    }
  }
}

class _CroquiGridPainter extends CustomPainter {
  final int comprimento, largura;
  final double cellSize;
  _CroquiGridPainter({required this.comprimento, required this.largura, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final sw = (cellSize * 0.04).clamp(0.3, 1.5);
    final paint = Paint()..color = const Color(0xFFB0BEC5)..strokeWidth = sw;
    for (int i = 0; i <= largura; i++) canvas.drawLine(Offset(0, i * cellSize), Offset(size.width, i * cellSize), paint);
    for (int i = 0; i <= comprimento; i++) canvas.drawLine(Offset(i * cellSize, 0), Offset(i * cellSize, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
