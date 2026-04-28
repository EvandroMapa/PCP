// Modelos de dados para o Plano de Corte.

/// Representa uma barra de matéria prima disponível.
class MateriaPrimaBarraModel {
  final double comprimento; // em mm ou metros (unidade consistente)
  final int? quantidade; // null = ilimitado
  int quantidadeUsada;

  MateriaPrimaBarraModel({
    required this.comprimento,
    this.quantidade,
    this.quantidadeUsada = 0,
  });

  bool get isIlimitado => quantidade == null;

  int get quantidadeDisponivel =>
      isIlimitado ? 999999 : (quantidade! - quantidadeUsada);

  bool get temDisponivel => quantidadeDisponivel > 0;

  MateriaPrimaBarraModel copyWith({
    double? comprimento,
    int? quantidade,
    int? quantidadeUsada,
  }) {
    return MateriaPrimaBarraModel(
      comprimento: comprimento ?? this.comprimento,
      quantidade: quantidade ?? this.quantidade,
      quantidadeUsada: quantidadeUsada ?? this.quantidadeUsada,
    );
  }
}

/// Representa um corte a ser feito (peça demandada).
class PecaDemandaModel {
  final String elementoNome;
  final String posicaoNome;
  final String numeroOs;
  final String pedidoLocalizador;
  final double comprCorte;
  final int quantidade; // qtde de peças (considerando qtde do elemento)

  PecaDemandaModel({
    required this.elementoNome,
    required this.posicaoNome,
    required this.numeroOs,
    required this.pedidoLocalizador,
    required this.comprCorte,
    required this.quantidade,
  });
}

/// Representa um corte individual alocado numa barra.
class CorteAlocadoModel {
  final PecaDemandaModel peca;
  final double comprCorte;

  CorteAlocadoModel({
    required this.peca,
    required this.comprCorte,
  });
}

/// Representa uma barra usada no plano com seus cortes alocados.
class BarraUsadaModel {
  final double comprimentoTotal;
  final int indiceBarra; // índice no estoque original
  final List<CorteAlocadoModel> cortes;

  BarraUsadaModel({
    required this.comprimentoTotal,
    required this.indiceBarra,
    this.cortes = const [],
  });

  double get comprimentoUsado =>
      cortes.fold(0.0, (sum, c) => sum + c.comprCorte);

  double get sobra => comprimentoTotal - comprimentoUsado;

  double get percentualUso =>
      comprimentoTotal > 0 ? (comprimentoUsado / comprimentoTotal) * 100 : 0;
}

/// Resultado completo do plano de corte.
class PlanoCorteResultado {
  final List<BarraUsadaModel> barrasUsadas;
  final List<PecaDemandaModel> pecasNaoAlocadas; // peças que faltaram barra
  final double totalComprimentoUsado;
  final double totalSobra;
  final int totalBarrasUsadas;

  PlanoCorteResultado({
    required this.barrasUsadas,
    required this.pecasNaoAlocadas,
    required this.totalComprimentoUsado,
    required this.totalSobra,
    required this.totalBarrasUsadas,
  });

  bool get temFalta => pecasNaoAlocadas.isNotEmpty;

  double get percentualAproveitamento {
    final totalDisponivel =
        barrasUsadas.fold(0.0, (sum, b) => sum + b.comprimentoTotal);
    return totalDisponivel > 0
        ? (totalComprimentoUsado / totalDisponivel) * 100
        : 0;
  }
}
