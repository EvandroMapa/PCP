
import 'dart:convert';

// Mocking the problematic logic
class StepModel {
  final int index;
  StepModel(this.index);
}

class ConfigItem {
  final StepModel? step;
  ConfigItem(this.step);
}

class AutomatizacaoConfig {
  final ConfigItem produtoPedidoSeparado;
  AutomatizacaoConfig(this.produtoPedidoSeparado);
}

// Simulated PedidoModel logic
class PedidoModel {
  final StepModel step;
  final AutomatizacaoConfig automatizacaoConfig;

  PedidoModel(this.step, this.automatizacaoConfig);

  bool isAguardandoEntradaProducao() {
    print('Testando isAguardandoEntradaProducao...');
    // A linha 108 original era: if (step.index >= automatizacaoConfig.produtoPedidoSeparado.step!.index)
    // Vamos simular o crash:
    try {
      if (step.index >= automatizacaoConfig.produtoPedidoSeparado.step!.index) {
        return false;
      }
    } catch (e) {
      print('CRASH DETECTADO NA LOGICA DO PEDIDO: $e');
      return true;
    }
    return true;
  }
}

void main() {
  print('--- SIMULADOR DE ERRO DE NULO ---');
  
  final stepAtual = StepModel(5);
  
  // Caso 1: Configuração com Step nulo (Causa o erro !)
  print('\nCenário 1: Step de configuração é NULO (Simulando erro !)');
  final configErro = AutomatizacaoConfig(ConfigItem(null));
  final pedido1 = PedidoModel(stepAtual, configErro);
  pedido1.isAguardandoEntradaProducao();

  // Caso 2: Como deveria ser (Seguro)
  print('\nCenário 2: Testando correção sugerida (Acesso Seguro ?.)');
  try {
    if (stepAtual.index >= (configErro.produtoPedidoSeparado.step?.index ?? 0)) {
       print('Resultado Seguro: OK');
    }
  } catch (e) {
    print('Erro inesperado: $e');
  }
  
  print('\n--- FIM DO TESTE ---');
}
