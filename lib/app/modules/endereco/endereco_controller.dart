import 'dart:developer';

import 'package:aco_plus/app/core/client/http/viacep/viacep_provider.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/models/endereco_model.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

final enderecoCtrl = EnderecoController();

class EnderecoController {
  static final EnderecoController _instance = EnderecoController._();

  EnderecoController._();

  factory EnderecoController() => _instance;

  final AppStream<EnderecoCreateModel> enderecoCreateStream =
      AppStream<EnderecoCreateModel>();
  EnderecoCreateModel get form => enderecoCreateStream.value;

  /// Snapshot dos valores iniciais para detectar se houve alteração
  String _snapshotInicial = '';

  void onInitEndereco(EnderecoModel? endereco) {
    enderecoCreateStream.add(
      endereco != null
          ? EnderecoCreateModel.edit(endereco)
          : EnderecoCreateModel(),
    );
    _snapshotInicial = _gerarSnapshot(form);
  }

  String _gerarSnapshot(EnderecoCreateModel f) =>
      '${f.cep.text}|${f.logradouro.text}|${f.bairro.text}|${f.localidade.text}|${f.estado.text}|${f.numero.text}|${f.complemento.text}|${f.lat.text}|${f.lon.text}';

  bool get houveMudanca => _gerarSnapshot(form) != _snapshotInicial;

  List<EnderecoModel> getOrdensFiltered(
    String search,
    List<EnderecoModel> ordens,
  ) {
    if (search.length < 3) return ordens;
    List<EnderecoModel> filtered = [];
    for (final endereco in ordens) {
      if (endereco.toString().toCompare.contains(search.toCompare)) {
        filtered.add(endereco);
      }
    }
    return filtered;
  }

  Future<void> onConfirm(value) async {
    try {
      onValidEndereco();

      // Se lat/lon não preenchidos, tenta geocodificar automaticamente
      final latAtual = double.tryParse(form.lat.text) ?? 0.0;
      final lonAtual = double.tryParse(form.lon.text) ?? 0.0;
      if (latAtual == 0.0 && lonAtual == 0.0) {
        final coords = await _geocodificar();
        if (coords != null) {
          form.lat.text = coords.$1.toString();
          form.lon.text = coords.$2.toString();
          enderecoCreateStream.update();
        }
      }

      Navigator.pop(value, enderecoCreateStream.value.toEndereco());
      NotificationService.showPositive(
        'Endereco ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro ao ${form.isEdit ? 'editar' : 'criar'} endereco',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  /// Monta o endereço completo e chama a API de Geocoding do Google.
  /// Retorna (lat, lon) ou null se não encontrar.
  Future<(double, double)?> _geocodificar() async {
    try {
      final partes = [
        form.logradouro.text,
        form.numero.text,
        form.bairro.text,
        form.localidade.text,
        form.estado.text,
        form.cep.text,
        'Brasil',
      ].where((p) => p.isNotEmpty).toList();

      if (partes.isEmpty) return null;

      final endereco = partes.join(', ');
      const apiKey = 'AIzaSyCU0z9swWm0LqdOkXIeoDuRJkBnqHuMvzw';
      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(endereco)}&key=$apiKey';

      final response = await Dio().get(url);
      final results = response.data['results'] as List?;

      if (results == null || results.isEmpty) return null;

      final location = results.first['geometry']['location'];
      final lat = (location['lat'] as num).toDouble();
      final lon = (location['lng'] as num).toDouble();

      log('[Geocoding] $endereco → lat=$lat lon=$lon');
      return (lat, lon);
    } catch (e) {
      log('[Geocoding] erro: $e');
      return null;
    }
  }

  // ── Google Places Autocomplete ────────────────────────────────────────────

  static const _apiKey = 'AIzaSyCU0z9swWm0LqdOkXIeoDuRJkBnqHuMvzw';

  /// Busca sugestões de lugares pelo texto digitado.
  Future<List<PlaceSugestao>> buscarSugestoes(String texto) async {
    if (texto.length < 3) return [];
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(texto)}'
          '&language=pt-BR'
          '&components=country:br'
          '&key=$_apiKey';
      final res = await Dio().get(url);
      final predictions = res.data['predictions'] as List? ?? [];
      return predictions
          .map((p) => PlaceSugestao(
                placeId: p['place_id'] as String,
                descricao: p['description'] as String,
              ))
          .toList();
    } catch (e) {
      log('[Places] erro autocomplete: $e');
      return [];
    }
  }

  /// Ao selecionar um lugar, busca os detalhes e preenche todos os campos.
  Future<void> selecionarLugar(PlaceSugestao sugestao) async {
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${sugestao.placeId}'
          '&language=pt-BR'
          '&fields=geometry,address_components,formatted_address'
          '&key=$_apiKey';
      final res = await Dio().get(url);
      final result = res.data['result'];
      if (result == null) return;

      // Coordenadas
      final loc = result['geometry']['location'];
      form.lat.text = (loc['lat'] as num).toString();
      form.lon.text = (loc['lng'] as num).toString();

      // Componentes do endereço
      final components = result['address_components'] as List? ?? [];
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

      form.logradouro.text = logradouro;
      form.numero.text = numero;
      form.bairro.text = bairro;
      form.localidade.text = cidade;
      form.estado.text = estado;
      if (cep.isNotEmpty) form.cep.text = cep;

      enderecoCreateStream.update();
      log('[Places] selecionado: ${sugestao.descricao} → lat=${form.lat.text} lon=${form.lon.text}');
    } catch (e) {
      log('[Places] erro detalhes: $e');
    }
  }

  void onValidEndereco() {
    try {} catch (e) {
      NotificationService.showNegative(
        'Erro ao ${form.isEdit ? 'editar' : 'criar'} endereco',
        e.toString(),
        position: NotificationPosition.bottom,
      );
      rethrow;
    }
  }

  void onSearchCEP(String cep) async {
    final response = await ViacepProvider.getEndereco(cep);
    if (response != null) {
      final endereco = EnderecoCreateModel.fromViacep(response);
      enderecoCreateStream.add(endereco);
    } else {
      NotificationService.showNegative(
        'Erro na chamada',
        'Nao foi possivel buscar endereço',
      );
    }
  }
}

/// Representa uma sugestão do Google Places Autocomplete.
class PlaceSugestao {
  final String placeId;
  final String descricao;
  const PlaceSugestao({required this.placeId, required this.descricao});
}

