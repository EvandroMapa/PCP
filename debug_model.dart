
import 'dart:convert';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/cliente/obra_model.dart';

void main() {
  print('--- INICIANDO TESTE DE MODELO LOCAL ---');
  
  try {
    print('1. Criando Produto dummy...');
    final produto = ProdutoModel(
      id: 'prod123',
      nome: 'Produto Teste',
      descricao: 'Descrição Teste',
      massaFinal: 10.0,
    );

    print('2. Criando PedidoProduto dummy...');
    final pedidoProduto = PedidoProdutoModel(
      id: 'pp123',
      pedidoId: 'ped123',
      clienteId: 'cli123',
      obraId: 'obr123',
      produto: produto,
      statusess: [],
      qtde: 5.0,
    );

    print('3. Testando PedidoProduto.toSupabaseMap()...');
    final ppMap = pedidoProduto.toSupabaseMap('ped123');
    print('Sucesso: $ppMap');

    print('\n4. Criando Pedido dummy...');
    final pedido = PedidoModel(
      id: 'ped123',
      localizador: 'LOC123',
      descricao: 'Pedido Teste',
      createdAt: DateTime.now(),
      cliente: ClienteModel(id: 'cli123', nome: 'Cliente Teste', fone: '', email: '', obras: []),
      obra: ObraModel(id: 'obr123', nome: 'Obra Teste', status: null),
      produtos: [pedidoProduto],
      statusess: [],
      steps: [],
      tags: [],
      checks: [],
      comments: [],
      users: [],
      histories: [],
      isArchived: false,
      archives: [],
      pedidosVinculados: [],
      pedidosFilhos: [],
    );

    print('5. Testando Pedido.toSupabaseMap()...');
    final pMap = pedido.toSupabaseMap();
    print('Sucesso: $pMap');

    print('\n--- TODOS OS TESTES PASSARAM LOCALMENTE ---');
  } catch (e, stack) {
    print('\n!!! ERRO DETECTADO !!!');
    print('Mensagem: $e');
    print('Stack Trace:\n$stack');
  }
}
