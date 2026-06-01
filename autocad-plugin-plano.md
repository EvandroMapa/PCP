# Plugin AutoCAD para PCP — Plano de Implementação

## Objetivo

Criar um plugin AutoCAD **independente do SPE** que permita ao usuário:
1. Selecionar uma área do desenho no AutoCAD
2. Exportar essa área como **PNG** via PlotEngine nativo
3. Fazer upload para o **Supabase Storage** do PCP (bucket `elementos`)
4. Registrar na tabela `elemento_arquivos` — aparece automaticamente na aba Elementos do pedido no app

---

## Estratégia: Reaproveitar a estrutura do SpePlugin

O `SpePlugin` (SPE) já tem toda a infraestrutura pronta:
- HTTP client para Supabase
- Leitura de configurações (URL + Key)
- Instalador (bat + bundle)
- AssemblyResolve para .NET 4.8
- Suporte a net8.0-windows e net48

**Vamos copiar a estrutura e adaptar para o PCP**, criando um projeto `PcpPlugin` separado.

---

## Onde ficará o código

```
d:\DESENVOLVIMENTO\pcp\
└── autocad-plugin\              ← novo (copiar de SPE e adaptar)
    ├── PcpPlugin\               ← projeto C#
    │   ├── PcpPlugin.csproj
    │   ├── Plugin.cs
    │   ├── GlobalUsings.cs
    │   ├── Servicos\
    │   │   ├── SupabaseClient.cs
    │   │   ├── ConfigService.cs
    │   │   └── StorageClient.cs  ← NOVO: upload de arquivo
    │   └── Comandos\
    │       └── ComandoPdf.cs     ← NOVO: PCP_PDF
    ├── libs\acad2022\            ← copiar de SPE (acmgd, accoremgd, acdbmgd)
    ├── dist\                     ← pacote de distribuição
    ├── deploy.ps1
    └── instalar.bat
```

---

## Comandos do PcpPlugin

### `PCP_PDF` — Exportar área como imagem e enviar ao Supabase

**Fluxo:**
```
1. PCP_PDF
2. "Código do pedido: " → usuário digita (ex: 1042)
3. Plugin busca o pedido no Supabase → confirma
4. "Primeiro canto:" → clique
5. "Segundo canto:" → clique + arraste
6. Plugin exporta a janela selecionada → PNG (via PlotEngine)
7. Upload para Supabase Storage → bucket: pcp-plantas
8. Salva URL na tabela `pedidos_plantas` (ou campo da tabela de pedidos)
9. App PCP mostra a imagem vinculada ao pedido
```

---

## Implementação Técnica

### 1. Exportar área para PNG

Usando o `PlotEngine` nativo do AutoCAD com o plotter `PublishToWeb PNG.pc3`:

```csharp
var ps = new PlotSettings(false);
var psv = PlotSettingsValidator.Current;
psv.SetCurrentStyleSheet(ps, "monochrome.ctb");
psv.SetPlotWindowArea(ps, pt1, pt2);
psv.SetPlotType(ps, PlotType.Window);
psv.SetUseStandardScale(ps, true);
psv.SetStdScaleType(ps, StdScaleType.ScaleToFit);
psv.SetPlotPaperUnits(ps, PlotPaperUnit.Millimeters);
psv.SetCurrentStyleSheet(ps, "monochrome.ctb");
// Configurar plotter PNG
psv.SetPlotConfigurationName(ps, "PublishToWeb PNG.pc3", "1024.00 x 768.00 Pixels");

// Gerar arquivo em temp
var plotInfo = new PlotInfo { Layout = layoutId };
plotInfo.OverrideSettings = ps;
var engine = PlotFactory.CreatePublishEngine();
engine.BeginPlot(null, null);
engine.BeginDocument(plotInfo, doc.Name, null, 1, true, tempPath);
// ...
engine.EndDocument(null);
engine.EndPlot(null);
```

### 2. Upload para Supabase Storage

> Bucket: **`elementos`** (já existe no PCP)
> Path: `elementos/{elementoId}/{nomeArquivo}.png`

```csharp
// PUT /storage/v1/object/elementos/{elementoId}/{filename}
var bytes = File.ReadAllBytes(tempPath);
var content = new ByteArrayContent(bytes);
content.Headers.ContentType = new MediaTypeHeaderValue("image/png");
http.DefaultRequestHeaders.Add("x-upsert", "true");
var response = http.PutAsync(
    $"{supabaseUrl}/storage/v1/object/elementos/{elementoId}/{filename}",
    content).Result;
// URL pública: {supabaseUrl}/storage/v1/object/public/elementos/{elementoId}/{filename}
```

### 3. Registrar na tabela `elemento_arquivos`

Essa tabela já é lida pelo PCP na aba Elementos do pedido.

```csharp
// POST /rest/v1/elemento_arquivos
var body = JsonSerializer.Serialize(new {
    elemento_id = elementoId,
    nome = nomeArquivo,           // ex: "V101_CAD_20260529.png"
    url = publicUrl,
    tamanho = bytes.Length,
    tipo = "image/png",
    extensao = "png"
    // criado_em → gerado automaticamente pelo Supabase
});
http.PostAsync($"{supabaseUrl}/rest/v1/elemento_arquivos",
    new StringContent(body, Encoding.UTF8, "application/json")).Wait();
```

---

## Mapeamento PCP ↔ Plugin

| Item | SpePlugin | PcpPlugin |
|------|-----------|----------|
| Namespace | `SpePlugin` | `PcpPlugin` |
| Assembly | `SpePlugin.dll` | `PcpPlugin.dll` |
| Comandos | `SPE`, `SPE_BLOCO`, `SPETOTAL` | `PCP_IMG` |
| Dados enviados | JSON (armaduras) | PNG (imagem do desenho) |
| Tabela principal | `elementos`, `posicoes` | `elemento_arquivos` |
| Storage bucket | — | `elementos` |
| Storage path | — | `elementos/{elementoId}/` |
| Config key URL | `plugin_cad_url` | `pcp_cad_url` |
| Config key token | `plugin_cad_key` | `pcp_cad_key` |

---

## Fluxo do Comando `PCP_IMG` (detalhado)

```
1. Usuário digita: PCP_IMG
2. "Codigo do elemento: " → usuário digita (ex: V101)
3. Plugin busca em GET /rest/v1/elementos?nome=eq.V101
4. Mostra: "V101 – Pedido #1042 – Cliente XYZ. Correto? [Sim/Nao]"
5. "Primeiro canto:" → clique no CAD
6. "Segundo canto:" → clique + arraste
7. Plugin chama PlotEngine → salva PNG em temp
8. Upload → Storage: elementos/{elementoId}/V101_CAD_20260529_143022.png
9. POST → elemento_arquivos (elementoId, nome, url, tamanho, tipo, extensao)
10. "[OK] Imagem enviada! Ja aparece no app PCP."
```

## Passos de Implementação

- [ ] 1. Criar `d:\DESENVOLVIMENTO\pcp\autocad-plugin\PcpPlugin\`
- [ ] 2. Copiar infraestrutura do SpePlugin (csproj, Plugin.cs, GlobalUsings.cs, Servicos/)
- [ ] 3. Adaptar namespace → `PcpPlugin`, comandos → `PCP_*`
- [ ] 4. Implementar `Servicos/StorageClient.cs` — upload PNG para Supabase Storage
- [ ] 5. Implementar `Comandos/ComandoImg.cs` — comando `PCP_IMG` completo
- [ ] 6. Adicionar configs `pcp_cad_url` e `pcp_cad_key` no Supabase PCP
- [ ] 7. Compilar (net48 + net8.0-windows), testar localmente
- [ ] 8. Montar `dist/` com instalador (reusar instalar.bat do SPE)
- [ ] 9. *(Opcional)* No app Flutter PCP: a imagem já aparece em `elemento.arquivos` — nenhuma mudança de UI necessária se o FlutterWidget já exibe os arquivos do elemento

## Pré-requisitos no Supabase PCP

- [x] Bucket `elementos` — **já existe** (PCP já usa `SupabaseStorageService.uploadFile` com path `elementos/{id}`)
- [x] Tabela `elemento_arquivos` — **já existe** com campos: `elemento_id, nome, url, tamanho, tipo, extensao`
- [ ] Config `pcp_cad_url` e `pcp_cad_key` na tabela `configs` (igual ao SPE)
