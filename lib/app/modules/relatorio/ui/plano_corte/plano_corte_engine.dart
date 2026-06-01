import 'package:aco_plus/app/modules/relatorio/ui/plano_corte/plano_corte_model.dart';

/// Motor de cálculo do Plano de Corte.
///
/// Utiliza o algoritmo First Fit Decreasing (FFD) adaptado para
/// priorizar barras com quantidade limitada antes das ilimitadas.
/// A ordem de prioridade dentro de cada grupo (limitadas / ilimitadas)
/// é a mesma em que o estoque é fornecido — ou seja, o usuário controla
/// a prioridade via reordenação na tela.
class PlanoCorteEngine {
  /// Gera o plano de corte.
  ///
  /// [demandas] – Lista de peças a serem cortadas (já expandidas por quantidade).
  /// [estoque] – Lista de barras de matéria prima disponíveis.
  static PlanoCorteResultado calcular({
    required List<PecaDemandaModel> demandas,
    required List<MateriaPrimaBarraModel> estoque,
  }) {
    // 1. Expandir demandas em cortes individuais e ordenar decrescente
    final List<PecaDemandaModel> cortesIndividuais = [];
    for (final d in demandas) {
      for (int i = 0; i < d.quantidade; i++) {
        cortesIndividuais.add(d);
      }
    }
    cortesIndividuais.sort((a, b) => b.comprCorte.compareTo(a.comprCorte));

    // 2. Separar estoque: limitadas primeiro, ilimitadas depois.
    // A ordem dentro de cada grupo é preservada conforme fornecida (definida pelo usuário).
    final limitadas = estoque
        .where((e) => !e.isIlimitado)
        .map((e) => e.copyWith(quantidadeUsada: 0))
        .toList();

    final ilimitadas = estoque
        .where((e) => e.isIlimitado)
        .map((e) => e.copyWith(quantidadeUsada: 0))
        .toList();

    // 3. Lista de barras já abertas (em uso)
    final List<BarraUsadaModel> barrasAbertas = [];
    final List<PecaDemandaModel> naoAlocadas = [];

    // Controle de quantas vezes cada barra limitada foi usada
    final Map<int, int> usoLimitadas = {};
    for (int i = 0; i < limitadas.length; i++) {
      usoLimitadas[i] = 0;
    }

    // 4. FFD – Para cada corte, tentar encaixar numa barra já aberta
    for (final corte in cortesIndividuais) {
      bool alocado = false;

      // 4a. Tentar encaixar em barra já aberta (melhor fit)
      int melhorIdx = -1;
      double menorSobra = double.infinity;
      for (int i = 0; i < barrasAbertas.length; i++) {
        final sobra = barrasAbertas[i].sobra - corte.comprCorte;
        if (sobra >= 0 && sobra < menorSobra) {
          menorSobra = sobra;
          melhorIdx = i;
        }
      }

      if (melhorIdx >= 0) {
        barrasAbertas[melhorIdx] = BarraUsadaModel(
          comprimentoTotal: barrasAbertas[melhorIdx].comprimentoTotal,
          indiceBarra: barrasAbertas[melhorIdx].indiceBarra,
          cortes: [
            ...barrasAbertas[melhorIdx].cortes,
            CorteAlocadoModel(peca: corte, comprCorte: corte.comprCorte),
          ],
        );
        alocado = true;
        continue;
      }

      // 4b. Abrir nova barra – primeiro tentar limitadas
      for (int i = 0; i < limitadas.length && !alocado; i++) {
        final barra = limitadas[i];
        if (barra.comprimento >= corte.comprCorte &&
            usoLimitadas[i]! < (barra.quantidade ?? 0)) {
          usoLimitadas[i] = usoLimitadas[i]! + 1;
          barrasAbertas.add(BarraUsadaModel(
            comprimentoTotal: barra.comprimento,
            indiceBarra: i,
            cortes: [
              CorteAlocadoModel(peca: corte, comprCorte: corte.comprCorte),
            ],
          ));
          alocado = true;
        }
      }

      // 4c. Se não conseguiu com limitadas, tentar ilimitadas
      if (!alocado) {
        for (final barra in ilimitadas) {
          if (barra.comprimento >= corte.comprCorte) {
            barrasAbertas.add(BarraUsadaModel(
              comprimentoTotal: barra.comprimento,
              indiceBarra: -1, // ilimitada
              cortes: [
                CorteAlocadoModel(peca: corte, comprCorte: corte.comprCorte),
              ],
            ));
            alocado = true;
            break;
          }
        }
      }

      // 4d. Se não alocou de jeito nenhum, peça fica faltando
      if (!alocado) {
        naoAlocadas.add(corte);
      }
    }

    // 5. Ordenar resultado pela prioridade da matéria prima:
    //    menor indiceBarra (= posição mais alta na lista do usuário) vem primeiro;
    //    ilimitadas (indiceBarra == -1) ficam sempre por último.
    barrasAbertas.sort((a, b) {
      if (a.indiceBarra == -1 && b.indiceBarra == -1) return 0;
      if (a.indiceBarra == -1) return 1;
      if (b.indiceBarra == -1) return -1;
      return a.indiceBarra.compareTo(b.indiceBarra);
    });

    // 6. Montar resultado
    final totalUsado =
        barrasAbertas.fold(0.0, (sum, b) => sum + b.comprimentoUsado);
    final totalSobra = barrasAbertas.fold(0.0, (sum, b) => sum + b.sobra);

    return PlanoCorteResultado(
      barrasUsadas: barrasAbertas,
      pecasNaoAlocadas: naoAlocadas,
      totalComprimentoUsado: totalUsado,
      totalSobra: totalSobra,
      totalBarrasUsadas: barrasAbertas.length,
    );
  }
}
