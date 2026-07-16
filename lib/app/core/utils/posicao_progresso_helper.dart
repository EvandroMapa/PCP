import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_bitola_status_model.dart';
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
/// [pedidoId] - ID do pedido (PedidoBitolaModel.pedidoId)
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
        case PosicaoStatus.aguardaSegundaEtapa:
          // Trata como aguardando no cálculo de progresso (OS entre etapas)
          pesoAguardando += peso;
          qtdAguardando++;
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

/// Calcula o consumo ajustado de um pedido_bitola, descontando o peso das
/// posições já marcadas como pronto (que já geraram baixa de estoque).
///
/// Quando o modo de apontamento é "por_os", cada posição marcada como pronto
/// faz `baixarEstoque()` individualmente, mas o pedido_bitola continua com
/// status `produzindo` até que TODAS as posições fiquem prontas.
/// Sem esse ajuste, o consumo previsto conta o total do pedido_bitola inteiro,
/// gerando contagem dupla com a baixa já realizada no saldo.
///
/// Para itens com status diferente de `produzindo`, ou sem posições,
/// retorna `produto.qtde` normalmente.
double calcularConsumoAjustado(PedidoBitolaModel produto) {
  // Só precisa ajustar itens em "produzindo" que podem ter posições parciais
  if (produto.statusess.last.status != PedidoBitolaStatus.produzindo) {
    return produto.qtde;
  }

  final progresso = calcularProgressoPosicoes(
    produto.pedidoId,
    produto.produto.id,
  );

  // Se não tem posições cadastradas, usa o valor original
  if (!progresso.hasData) return produto.qtde;

  // Desconta o peso das posições já prontas (já baixadas do estoque)
  final consumoRestante = produto.qtde - progresso.pesoPronto;
  return consumoRestante > 0 ? consumoRestante : 0;
}
