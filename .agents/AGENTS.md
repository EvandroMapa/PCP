# Diretrizes Técnicas do Projeto PCP

## 7. KANBAN DRAG/DROP — LOCK ANTI-FLICKERING (obrigatório)

### Problema resolvido (26/jun/2026)
O Kanban usa **UI otimista** + **Supabase Realtime**. Ao mover um cartão,
o estado local é atualizado imediatamente (`_onMovePedido`) e o Realtime
traz a confirmação do banco logo depois. Se o Realtime atualizar ANTES do
move otimista, o cartão "pisca" (aparece na origem, some, reaparece no destino).

### Mecanismo de lock (`isDropLocked`)
O controller usa `isDragging || _pendingDrop` para bloquear o listener do
Realtime durante o arrasto e por 3 segundos após o drop:
- `startDrag()` → `isDragging = true`
- `endDrag()` → `_pendingDrop = true`, `isDragging = false`, timer 3s
- Listener: `if (!isDropLocked) { updateKanban(); }`

### Regras obrigatórias ao alterar `kanban_controller.dart`
1. **NUNCA** converter `onWillAccept` ou qualquer validação síncrona chamada
   dentro de `onAccept` em `async`/`Future` sem renovar o lock.
   O `await` introduz um gap no event loop onde o Realtime pode interferir.
2. Se `onAccept` usar `await` antes de `_onMovePedido`, **DEVE** renovar
   o lock manualmente:
   ```dart
   _dropTimer?.cancel();
   _pendingDrop = true;
   // ... await ...
   _onMovePedido(...);
   _dropTimer?.cancel();
   _dropTimer = Timer(Duration(milliseconds: 3000), () => _pendingDrop = false);
   ```
3. Se a validação falhar após o `await`, ainda assim iniciar o timer de 3s
   para liberar o lock gradualmente (nunca setar `_pendingDrop = false` direto).
4. Após mudanças no mecanismo de drag/drop, SEMPRE testar com **restart completo**
   (não hot reload), pois o hot reload preserva timers e flags "sujas" em memória.

---

## 8. APONTAMENTO POR OS — LOCK EM DUAS CAMADAS (obrigatório)

### Problema resolvido (04/ago/2026)
A tela `OrdemPedidoElementosPage` usa **UI otimista** + **Supabase Realtime**.
Ao tocar num card de OS para mudar o status, o estado local é atualizado
imediatamente, mas o `_handlePosicaoRealtime` (em `ElementoSupabaseCollection`)
muta o cache global **diretamente**, ignorando qualquer lock apenas no stream listener.

Isso causava o bug: o operador tocava no card → `produzindo` → após ~2s voltava para
`aguardando` → voltava para `produzindo`. O ciclo acontecia porque:
1. Atualização otimista: cache = `produzindo`
2. Realtime chega → `_handlePosicaoRealtime` muta cache = `aguardando` (estado anterior)
3. Timer de re-sync lê o cache contaminado → UI mostra `aguardando`
4. Novo Realtime (confirmação real) → cache = `produzindo` novamente

### Mecanismo de lock em duas camadas

**Camada 1 — Stream listener** (`_elemsSubscription` no dialog):
```dart
if (_isStatusLocked) return;  // bloqueia rebuild do widget
```

**Camada 2 — Cache global** (`ElementoSupabaseCollection.isStatusChanging`):
```dart
// Em _handlePosicaoRealtime:
if (isStatusChanging) return;  // bloqueia mutação direta do cache global
```

### Fluxo correto com o lock duplo
- `_ativarLock()` → `_isChangingStatus = true` + `ElementoSupabaseCollection.isStatusChanging = true`
- Realtime chega durante o lock → **bloqueado em ambas as camadas** → cache não contaminado
- `_liberarLock()` → timer 4s → ao expirar: libera `isStatusChanging = false` → re-sync do cache (agora limpo) → libera stream
- `dispose()` → **sempre** libera `isStatusChanging = false` para não bloquear o Realtime indefinidamente

### Regras obrigatórias em qualquer tela que use `elemento_posicoes` com UI otimista
1. **SEMPRE implementar o lock em duas camadas** — bloquear só o stream listener NÃO é suficiente.
   O `_handlePosicaoRealtime` muta o cache global e precisa do `isStatusChanging` para ser bloqueado.
2. **NUNCA liberar `isStatusChanging = false` fora do timer** (exceto no `dispose`).
   Liberar antes do timer deixa uma janela onde o Realtime contamina o cache antes do re-sync.
3. **O timer deve ser ≥ 4s** para cobrir toda a cadeia:
   escrita Supabase (~300ms) + evento Realtime (~200ms) + debounce `_updateStreams` (1.5s) + fetch de elementos (~2s).
4. **O re-sync final no timer deve ler APÓS liberar `isStatusChanging`**, para que o
   cache já reflita eventos Realtime externos (outros dispositivos) recebidos durante o lock.
5. Testar com **restart completo** — hot reload preserva timers e flags em memória.

### Arquivos-chave
- `elemento_supabase_collection.dart` → `static bool isStatusChanging`
- `ordem_pedido_elementos_dialog.dart` → `_ativarLock()`, `_liberarLock()`, `dispose()`

---

## 9. ARMAÇÃO — LOCK EM DUAS CAMADAS + TOUCH VS MOUSE (obrigatório)

### Problema resolvido (05/ago/2026)
A tela `ArmacaoElementosPage` usa **UI otimista** + **Supabase Realtime**.
No **tablet (touch)** funcionava, mas no **PC (mouse)** o status revertia após o clique.

A causa raiz tinha **três componentes**:

1. **`setState` stale no picker de status**: após `await updateElementoStatus`, o
   `setState(() {})` forçava rebuild com o `elemento` capturado na closure (estado anterior).
   No PC o timing coincidia com o Realtime chegando → reversão visual.

2. **Lock ativado após o primeiro `await`**: `_ativarStatusLock()` estava após a busca
   de config no banco. Havia uma janela aberta onde o Realtime chegava antes do lock.

3. **`_updateStreams` não respeitava `isStatusChanging`**: o re-fetch completo de elementos
   (debounce 1.5s + fetch pesado) terminava APÓS o lock local expirar e sobrescrevia
   o `elementosStream` com o estado anterior. No PC (rede rápida), esse ciclo era mais
   rápido que no tablet, expondo o bug.

### Mecanismo de lock em duas camadas (igual ao item 8)

**Camada 1 — `_statusLock`** (local, `ArmacaoController`):
```dart
AppSupabaseClient.elementos.dataStream.listen.listen((allElementos) {
  if (_statusLock) return;  // bloqueia listener local
  ...
});
```

**Camada 2 — `ElementoSupabaseCollection.isStatusChanging`** (global):
```dart
// Em _handleElementoRealtime e _handlePosicaoRealtime:
if (isStatusChanging) return;

// Em _updateStreams (NOVO guard):
if (isStatusChanging) return;  // bloqueia re-fetch completo durante troca
```

### Regras obrigatórias

1. **Lock SEMPRE na primeira linha** de `_applyStatusUpdate` (antes de qualquer `await`).
   Qualquer `await` anterior cria janela aberta para o Realtime interferir.
2. **NUNCA usar `setState(() {})` após `await` de update** em telas com `StreamOut`.
   O `StreamOut` já reage ao stream — o `setState` extra causa rebuild com closure stale.
3. **`_updateStreams` deve verificar `isStatusChanging`** antes de executar o re-fetch.
   Sem isso, no PC (rede rápida), o fetch termina após o lock local expirar.
4. **`dispose()` sempre chama `liberarLockSeAtivo()`** para não bloquear o Realtime
   indefinidamente caso o usuário saia durante uma troca de status.
5. Testar em **PC com mouse** além de tablet — timing é diferente e expõe bugs de janela.

### Arquivos-chave
- `armacao_controller.dart` → `_ativarStatusLock()`, `_liberarStatusLock()`, `liberarLockSeAtivo()`
- `armacao_elementos_page.dart` → `dispose()` chama `liberarLockSeAtivo()`
- `elemento_supabase_collection.dart` → guard `isStatusChanging` em `_updateStreams`

---

## 10. REALTIME CROSS-DEVICE — CHANNEL LISTENER CIRÚRGICO (obrigatório)

### Problema resolvido (05/ago/2026)
O `.stream(primaryKey: ['id'])` do Supabase baixa **toda a tabela** a cada mudança,
gerando um re-fetch pesado com debounce de 1.5s + tempo de fetch. Resultado:
atualização cross-device (ex: PC → tablet) demorava **~3-4 segundos**.

### Solução: channel listener com atualização pontual no cache

```dart
// ❌ ANTES (lento — baixa tabela inteira):
SupabaseService.client.from('elementos').stream(primaryKey: ['id'])
    .listen((_) => _updateStreams());

// ✅ DEPOIS (rápido — recebe só o registro alterado):
SupabaseService.client
    .channel('elementos_realtime')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'elementos',
      callback: _handleElementoRealtime,
    )
    .subscribe();
```

No `_handleElementoRealtime`:
- **UPDATE** → atualiza cirurgicamente `status`, `qtde_pronto`, `qtde_armando` no cache → `dataStream.add(data)` → **~300ms**
- **INSERT/DELETE** → fallback para `_updateStreams()` (menos frequentes, mais complexos)
- Sempre verificar `if (isStatusChanging) return;` antes de qualquer mutação

### Regras obrigatórias

1. **Preferir channel listener** a `.stream()` para tabelas grandes ou com muitas mudanças.
   `.stream()` é conveniente mas custoso — sempre baixa a tabela completa.
2. **Guard `isStatusChanging`** obrigatório no handler para não processar o próprio Realtime
   durante troca de status (o dispositivo remoto tem `isStatusChanging=false` e processa normalmente).
3. **INSERT/DELETE fazem fallback** para `_updateStreams()` pois precisam buscar dados
   relacionados (posições, arquivos) que não chegam no payload do Realtime.
4. Verificar se a tabela está na **Publication de Realtime** do Supabase
   (`Database → Publications → supabase_realtime`) — sem isso o channel nunca dispara.

### Arquivos-chave
- `elemento_supabase_collection.dart` → `_handleElementoRealtime()`, `listen()`
