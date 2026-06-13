# 📱 Estudo: App Mobile PCP
**Data:** 13/06/2026  
**Status:** Em análise — não iniciado

---

## Visão Geral

O projeto já é Flutter — o mesmo código pode compilar para Android e iOS.
A maior parte da lógica (Supabase, autenticação, realtime, controllers) funciona nativamente.
O esforço principal é adaptar a **UI** para telas menores e isolar as dependências web (`dart:html`).

---

## Módulos propostos

### 📱 Módulo Operador
**O que já existe no web:**
- Lista de ordens de produção (filtradas por status)
- Apontamento de status por pedido ou por OS
- Toggle "Prontos ocultos" na AppBar
- Fullscreen (web only — substituir por tela bloqueada em portrait no mobile)

**Adaptações necessárias para mobile:**
- Layout de cards já é responsivo → mínimo ajuste
- Substituir fullscreen por `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`
- Dialog de status (`_OperadorStatusDialog`) → funciona sem alteração

**Esforço estimado:** 🟢 Baixo

---

### 🔧 Módulo Armador
**O que já existe no web:**
- `armacao_page.dart` — lista de pedidos para armar (SPE/elementos)
- `armacao_elementos_page.dart` — detalhe dos elementos a armar (35 KB de código)
- Controller com lógica de status e apontamento

**Adaptações necessárias para mobile:**
- Tela de elementos é densa → precisaria de scroll e cards responsivos
- Verificar se usa `dart:html` (provável apenas para PDF/download)

**Esforço estimado:** 🟡 Médio

---

### 📊 Módulo ADM
**Funcionalidades sugeridas para mobile:**

| Funcionalidade | Status no web | Esforço mobile |
|---|---|---|
| Dashboard KPIs (pedidos, kg em produção) | ✅ Existe | 🟢 Baixo — só reestilizar |
| Ranking de clientes | ✅ Existe | 🟢 Baixo |
| Lista de ordens ativas | ✅ Existe | 🟢 Baixo |
| Kanban resumido (só visualizar) | ✅ Existe | 🟡 Médio |
| Gráfico de produção por bitola | ✅ Existe | 🟢 Baixo |
| Cadastros (pedidos, ordens) | ✅ Existe | 🔴 Alto — forms complexos |
| Relatório PDF | ✅ Existe | 🟡 Médio — `path_provider` |

**Recomendação:** No ADM mobile, focar em **visualização e aprovação**, não em cadastro completo.

---

## Dependências web que precisam de guard

```dart
// Padrão para isolar código web-only:
if (kIsWeb) {
  // dart:html, downloads, fullscreen
} else {
  // alternativa mobile
}
```

| Dependência | Ocorrência | Alternativa mobile |
|---|---|---|
| `dart:html` (download PDF) | `backup_controller`, `audit_service` | `path_provider` + `open_filex` |
| `dart:html` (fullscreen) | `base_page.dart` | `SystemChrome` immersive |
| `setWebTitle` | `ordem_page.dart` e outros | No-op no mobile |

---

## Arquitetura do app

### Opção A — App separado
Um novo projeto Flutter que **importa** os packages de lógica do PCP como dependência local. UI própria, mobile-first.

- ✅ UI limpa, sem herança de código web denso  
- ❌ Manter dois projetos

### Opção B — Build mobile do mesmo projeto *(recomendado)*
Adicionar `android/` e `ios/` ao projeto atual, com guards `kIsWeb`.

- ✅ Um único repositório  
- ✅ Compartilha toda a lógica de negócio sem duplicação  
- ⚠️ Risco de regredir funcionalidades web — testes necessários

> **Recomendação:** Opção B como ponto de partida.  
> Primeiro passo concreto: `flutter create . --platforms=android` e verificar erros.

---

## Plano de etapas sugerido

| Fase | Descrição | Estimativa |
|---|---|---|
| 1 | Habilitar Android no projeto | 1–2h |
| 2 | Guards `kIsWeb` em todo `dart:html` | 2–4h |
| 3 | Módulo Operador mobile | 4–8h |
| 4 | Módulo Armador mobile | 8–16h |
| 5 | Dashboard ADM mobile | 8–16h |
| 6 | Build & distribuição (APK/Play Store) | 4–8h |

**Total estimado:** 3 a 6 semanas de desenvolvimento iterativo.

---

## Perguntas a responder antes de iniciar

- [ ] **Android somente ou iOS também?** (iOS exige Mac + $99/ano Apple Developer)
- [ ] **Distribuição:** Google Play Store, APK direto, ou Firebase App Distribution (beta)?
- [ ] **Offline?** O app precisa funcionar sem internet?
- [ ] **ADM mobile:** só visualizar ou também criar/editar pedidos pelo app?
- [ ] **Nome do app / identidade visual separada** da plataforma web?

---

*Documento gerado em 13/06/2026. Para retomar este estudo, consultar este arquivo.*
