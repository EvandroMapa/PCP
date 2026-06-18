import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:flutter/material.dart';

/// Detalhe de uma produção individual (um pedido-bitola que ficou "Pronto")
class ProdutividadeDetalhe {
  final String ordemId;
  final String pedidoLocalizador;
  final BitolaModel bitola;
  final double kg;
  final double metros;
  final DateTime dataEncerramento;
  final UsuarioModel? operador;

  ProdutividadeDetalhe({
    required this.ordemId,
    required this.pedidoLocalizador,
    required this.bitola,
    required this.kg,
    required this.metros,
    required this.dataEncerramento,
    this.operador,
  });
}

/// Agrupamento por bitola
class ProdutividadePorBitola {
  final BitolaModel bitola;
  final double kg;
  final double metros;
  final int quantidade; // nº de produções

  ProdutividadePorBitola({
    required this.bitola,
    required this.kg,
    required this.metros,
    required this.quantidade,
  });
}

/// Agrupamento por dia
class ProdutividadePorDia {
  final DateTime data;
  final double kg;
  final double metros;
  final int quantidade;

  ProdutividadePorDia({
    required this.data,
    required this.kg,
    required this.metros,
    required this.quantidade,
  });
}

/// Resultado do relatório processado
class RelatorioProdutividadeModel {
  final double kgTotal;
  final double metrosTotal;
  final int qtdeProducoes;
  final List<ProdutividadePorBitola> porBitola;
  final List<ProdutividadePorDia> porDia;
  final List<ProdutividadeDetalhe> detalhes;
  final DateTime geradoEm;

  RelatorioProdutividadeModel({
    required this.kgTotal,
    required this.metrosTotal,
    required this.qtdeProducoes,
    required this.porBitola,
    required this.porDia,
    required this.detalhes,
  }) : geradoEm = DateTime.now();
}

/// ViewModel com filtros e resultado
class RelatorioProdutividadeViewModel {
  /// Período — padrão: segunda-feira da semana atual → hoje
  late DateTimeRange periodo;

  /// Bitolas — padrão: todas
  late List<BitolaModel> bitolas;

  /// Operador — null = todos
  UsuarioModel? operador;

  /// Exibir seção de filtros
  bool mostrarFiltro = true;

  /// Resultado processado
  RelatorioProdutividadeModel? relatorio;

  RelatorioProdutividadeViewModel() {
    final agora = DateTime.now();
    // Calcula a segunda-feira da semana atual
    // weekday: 1=seg, 7=dom
    final diasDesdeSegunda = agora.weekday - 1;
    final segunda = DateTime(
      agora.year,
      agora.month,
      agora.day - diasDesdeSegunda,
    );
    final hoje = DateTime(agora.year, agora.month, agora.day, 23, 59, 59);

    periodo = DateTimeRange(start: segunda, end: hoje);
    bitolas = FirestoreClient.bitolas.data.map((e) => e.copyWith()).toList();
  }
}
