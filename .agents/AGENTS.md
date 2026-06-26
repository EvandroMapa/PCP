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
