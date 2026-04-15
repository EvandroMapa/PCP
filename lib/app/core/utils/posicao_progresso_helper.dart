import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/modules/elemento/elemento_model.dart';

/// Resultado do cálculo de progresso por posições de produção.
class PosicaoProgressoResult {
  final double pesoAguardando;
  final double pesoProduzindo;
  final double pesoPronto;
  final int qtdAguardando;
  final int qtdProduzindo;
  final int qtdPronto;

  const PosicaoProgressoResult({
    this.pesoAguardando = 0,
    this.pesoProduzindo = 0,
    this.pesoPronto = 0,
    this.qtdAguardando = 0,
    this.qtdProduzindo = 0,
    this.qtdPronto = 0,
  });

  double get pesoTotal => pesoAguardando + pesoProduzindo + pesoPronto;
  int get qtdTotal => qtdAguardando + qtdProduzindo + qtdPronto;

  double get prcntAguardando => pesoTotal == 0 ? 0 : pesoAguardando / pesoTotal;
  double get prcntProduzindo => pesoTotal == 0 ? 0 : pesoProduzindo / pesoTotal;
  double get prcntPronto => pesoTotal == 0 ? 0 : pesoPronto / pesoTotal;

  /// Retorna true se existem posições (ou seja, o cálculo fracionado foi possível).
  bool get hasData => qtdTotal > 0;
}

/// Calcula o progresso de produção baseado nas posições (elemento_posicoes)
/// para um determinado pedido e bitola.
///
/// [pedidoId] - ID do pedido (PedidoProdutoModel.pedidoId)
/// [bitolaId] - ID do produto/bitola da ordem (OrdemModel.produto.id)
PosicaoProgressoResult calcularProgressoPosicoes(
    String pedidoId, String bitolaId) {
  final elementos = AppSupabaseClient.elementos.data
      .where((e) => e.pedidoId == pedidoId)
      .toList();

  if (elementos.isEmpty) return const PosicaoProgressoResult();

  double pesoAguardando = 0;
  double pesoProduzindo = 0;
  double pesoPronto = 0;
  int qtdAguardando = 0;
  int qtdProduzindo = 0;
  int qtdPronto = 0;

  for (final elemento in elementos) {
    for (final posicao in elemento.posicoes) {
      if (posicao.produtoId != bitolaId) continue;

      final peso = posicao.pesoKg * elemento.qtde;

      switch (posicao.status) {
        case PosicaoStatus.aguardando:
          pesoAguardando += peso;
          qtdAguardando++;
          break;
        case PosicaoStatus.produzindo:
          pesoProduzindo += peso;
          qtdProduzindo++;
          break;
        case PosicaoStatus.pronto:
          pesoPronto += peso;
          qtdPronto++;
          break;
      }
    }
  }

  return PosicaoProgressoResult(
    pesoAguardando: pesoAguardando,
    pesoProduzindo: pesoProduzindo,
    pesoPronto: pesoPronto,
    qtdAguardando: qtdAguardando,
    qtdProduzindo: qtdProduzindo,
    qtdPronto: qtdPronto,
  );
}

/// Calcula o progresso de produção para uma ordem inteira (múltiplos pedidos),
/// baseado nas posições de todos os produtos da ordem.
///
/// [pedidoIds] - Lista de pedidoIds dos produtos da ordem
/// [bitolaId] - ID do produto/bitola da ordem
PosicaoProgressoResult calcularProgressoOrdem(
    List<String> pedidoIds, String bitolaId) {
  double pesoAguardando = 0;
  double pesoProduzindo = 0;
  double pesoPronto = 0;
  int qtdAguardando = 0;
  int qtdProduzindo = 0;
  int qtdPronto = 0;

  for (final pedidoId in pedidoIds) {
    final result = calcularProgressoPosicoes(pedidoId, bitolaId);
    pesoAguardando += result.pesoAguardando;
    pesoProduzindo += result.pesoProduzindo;
    pesoPronto += result.pesoPronto;
    qtdAguardando += result.qtdAguardando;
    qtdProduzindo += result.qtdProduzindo;
    qtdPronto += result.qtdPronto;
  }

  return PosicaoProgressoResult(
    pesoAguardando: pesoAguardando,
    pesoProduzindo: pesoProduzindo,
    pesoPronto: pesoPronto,
    qtdAguardando: qtdAguardando,
    qtdProduzindo: qtdProduzindo,
    qtdPronto: qtdPronto,
  );
}
