# 📋 Estudo: Produção Parcial de Bitola (Apontamento Parcial OS/Pedido)

**Data do estudo:** 2026  
**Status:** Planejado — não iniciado  
**Palavras-chave:** `apontamento parcial`, `rodar parcial`, `permitirParcial`, `qtdeParcial`, `qtdeProduzida`

---

## Conceito

O planejista define que uma bitola deve ser produzida **parcialmente** (ex: 400 kg de 977 kg).  
O operador produz essa quantidade, o sistema acumula (`qtdeProduzida`) e repõe o status para  
`aguardandoProducao` até que toda a quantidade seja concluída.

---

## Migration SQL necessária (Supabase — tabela `pedido_bitolas`)

```sql
ALTER TABLE pedido_bitolas
  ADD COLUMN IF NOT EXISTS permitir_parcial boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS qtde_parcial float8 DEFAULT null,
  ADD COLUMN IF NOT EXISTS qtde_produzida float8 DEFAULT 0,
  ADD COLUMN IF NOT EXISTS mensagem_parcial text DEFAULT null;
```

---

## Arquivos a modificar/criar

| # | Arquivo | Tipo | O que muda |
|---|---------|------|------------|
| 1 | Supabase | Migration SQL | 4 novas colunas |
| 2 | `pedido_bitola_model.dart` | MODIFY | 4 campos + computed props (`qtdeAlvo`, `isCompleta`, `progressoTotal`) |
| 3 | `pedido_supabase_collection.dart` | MODIFY | Método `updateParcial` + lógica acumuladora no `updateProdutosStatus` |
| 4 | `pedido_controller.dart` | MODIFY | `onDefinirParcial` / `onRemoverParcial` |
| 5 | `pedido_bitolas_widget.dart` | MODIFY | Botão "Rodar Parcial" por bitola |
| 6 | `pedido_parcial_dialog.dart` | NEW | Dialog: qtde + mensagem para o operador |
| 7 | `ordem_controller.dart` | MODIFY | Produção com `qtdeAlvo` + acumulador + baixa de estoque parcial |
| 8 | `ordem_pedido_bitola_widget.dart` | MODIFY | Exibir "400 kg de 977 kg" + barra de progresso |
| 9 | `kanban_card_products_widget.dart` | MODIFY | Badge "400/977 kg" quando parcial ativo |
| 10 | `ordem_timeline_register.dart` | MODIFY | Tipo `producaoParcialConcluida` |

---

## Fluxo resumido

```
Planejista → "Rodar Parcial" (400 kg + mensagem)
  → Operador muda para "Produzindo" → alerta com mensagem do planejista
  → Operador marca "Pronto"
  → Sistema: qtdeProduzida += 400, baixa 400 kg do estoque
  → Se incompleto → volta para "Aguardando Produção" (flags limpas)
  → Se completo → "Pronto" definitivo
```

---

## Relacionado

- Estudo de Apontamento por OS (modo `por_os` vs `por_pedido`) → já implementado em `PreferencesService.apontamentoProducaoCD`
- Dialog de OS já existe: `ordem_pedido_elementos_dialog.dart`

---

*Para retomar: diga "produção parcial de bitola" ou "apontamento parcial OS/Pedido"*
