using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.PlottingServices;
using System.Text.Json;

namespace PcpPlugin.Comandos
{
    /// <summary>
    /// Comando PCP_IMG — Exporta uma área selecionada do AutoCAD como PNG
    /// e envia ao Supabase PCP, vinculando ao elemento informado.
    /// </summary>
    public class ComandoImg
    {
        // ═══════════════════════════════════════════════════════════════════
        // PCP_DIAG — diagnóstico de plotters disponíveis
        // ═══════════════════════════════════════════════════════════════════
        [CommandMethod("PCP_DIAG", CommandFlags.Modal)]
        public void PcpDiag()
        {
            var doc = Application.DocumentManager.MdiActiveDocument;
            var ed  = doc.Editor;
            var db  = doc.Database;
            var psv = PlotSettingsValidator.Current;

            // CRÍTICO: definir Working Database para o validator reconhecer os plotters
            HostApplicationServices.WorkingDatabase = db;

            ed.WriteMessage("\n=== PCP_DIAG — Diagnóstico de Plot ===\n");
            ed.WriteMessage($"WorkingDatabase setado: {db.Filename}\n");

            // ── Tentar direto com media name conhecido ──
            var testCombos = new[]
            {
                ("PublishToWeb PNG.pc3",              "1024.00 x 768.00 Pixels"),
                ("PublishToWeb PNG.pc3",              "640.00 x 480.00 Pixels"),
                ("PublishToWeb PNG.pc3",              "2048.00 x 1536.00 Pixels"),
                ("PublishToWeb PNG (Transparent).pc3","1024.00 x 768.00 Pixels"),
                ("DWG To PDF.pc3",                    "ISO A4 (210.00 x 297.00 MM)"),
                ("DWG To PDF.pc3",                    "ANSI A (8.50 x 11.00 Inches)"),
            };

            ed.WriteMessage("\n--- Testando combinações plotter+paper ---");
            foreach (var (dev, media) in testCombos)
            {
                var ps = new PlotSettings(true);
                try
                {
                    psv.SetPlotConfigurationName(ps, dev, media);
                    ed.WriteMessage($"\n  [OK] '{dev}' / '{media}'");
                }
                catch (System.Exception ex)
                {
                    ed.WriteMessage($"\n  [ERRO] '{dev}' / '{media}' → {ex.GetType().Name}: {ex.Message}");
                }
            }

            // ── Tentar com objeto Layout diretamente ──
            ed.WriteMessage("\n\n--- Testando via objeto Layout ---");
            using var tr = db.TransactionManager.StartTransaction();
            var layoutDict = (DBDictionary)tr.GetObject(db.LayoutDictionaryId, OpenMode.ForRead);
            foreach (DBDictionaryEntry entry in layoutDict)
            {
                var lo = (Layout)tr.GetObject(entry.Value, OpenMode.ForRead);
                if (!lo.ModelType) continue;

                ed.WriteMessage($"\n  Layout model: '{lo.LayoutName}'");

                // Tentar SetPlotConfigurationName no Layout object
                try
                {
                    var psTest = new PlotSettings(true);
                    psv.SetPlotConfigurationName(psTest, "PublishToWeb PNG.pc3", "1024.00 x 768.00 Pixels");
                    var mediaList = psv.GetCanonicalMediaNameList(psTest);
                    ed.WriteMessage($"\n  [OK] GetCanonicalMediaNameList: {mediaList.Count} itens");
                    foreach (string m in mediaList)
                        ed.WriteMessage($"\n    '{m}'");
                }
                catch (System.Exception ex)
                {
                    ed.WriteMessage($"\n  [ERRO] {ex.GetType().Name}: {ex.Message}");
                }
                break;
            }
            tr.Commit();

            ed.WriteMessage("\n\n=== Fim do diagnóstico ===\n");
        }


        // ═══════════════════════════════════════════════════════════════════
        // PCP_IMG — exportar imagem para elemento
        // ═══════════════════════════════════════════════════════════════════
        [CommandMethod("PCP_IMG", CommandFlags.Modal)]
        public void PcpImg()
        {
            var doc      = Application.DocumentManager.MdiActiveDocument;
            var ed       = doc.Editor;
            var db       = doc.Database;
            var supabase = new Servicos.SupabaseClient();

            ed.WriteMessage("\n=== PCP Plugin — Exportar Imagem para Elemento ===");
            ed.WriteMessage("\n  (ESC em qualquer etapa cancela)\n");

            // ── ETAPA 1: Localizador ────────────────────────────────────────
            string pedidoId;
            string pedidoLocalizador;

            while (true)
            {
                var optLoc = new PromptStringOptions("\nLocalizador do pedido: ") { AllowSpaces = true };
                var resLoc = ed.GetString(optLoc);
                if (resLoc.Status != PromptStatus.OK) { ed.WriteMessage("\n[CANCELADO]\n"); return; }

                var termo = resLoc.StringResult.Trim();
                if (string.IsNullOrEmpty(termo)) { ed.WriteMessage("  [!] Digite o localizador.\n"); continue; }

                ed.WriteMessage($"  Buscando '{termo}'...");
                System.Collections.Generic.List<System.Collections.Generic.Dictionary<string, object?>> pedidos;
                try { pedidos = supabase.BuscarPedidosPorLocalizador(termo); }
                catch (System.Exception ex) { ed.WriteMessage($"\n  [ERRO] {ex.Message}\n  Tente novamente.\n"); continue; }

                if (pedidos.Count == 0) { ed.WriteMessage($"\n  [!] Nenhum pedido encontrado com '{termo}'.\n"); continue; }

                ed.WriteMessage($"\n  {pedidos.Count} pedido(s):");
                for (int i = 0; i < pedidos.Count; i++)
                    ed.WriteMessage($"\n  [{i + 1}] {ExtrairString(pedidos[i], "localizador")}  —  {ExtrairString(pedidos[i], "descricao")}");
                ed.WriteMessage("\n");

                if (pedidos.Count == 1)
                {
                    pedidoId = ExtrairString(pedidos[0], "id");
                    pedidoLocalizador = ExtrairString(pedidos[0], "localizador");
                    ed.WriteMessage($"  Pedido: {pedidoLocalizador}");
                    break;
                }

                var optN = new PromptIntegerOptions($"\n  Escolha [1-{pedidos.Count}] ou ESC: ") { LowerLimit = 1, UpperLimit = pedidos.Count };
                var resN = ed.GetInteger(optN);
                if (resN.Status != PromptStatus.OK) { ed.WriteMessage("\n  Nova busca.\n"); continue; }

                pedidoId = ExtrairString(pedidos[resN.Value - 1], "id");
                pedidoLocalizador = ExtrairString(pedidos[resN.Value - 1], "localizador");
                ed.WriteMessage($"\n  [OK] Pedido: {pedidoLocalizador}");
                break;
            }

            // ── ETAPA 2: Elemento ───────────────────────────────────────────
            string elementoId;
            string elementoNome;

            while (true)
            {
                var optEl = new PromptStringOptions($"\nElemento em '{pedidoLocalizador}' (ex: V101): ") { AllowSpaces = false };
                var resEl = ed.GetString(optEl);
                if (resEl.Status != PromptStatus.OK) { ed.WriteMessage("\n[CANCELADO]\n"); return; }

                var nomeEl = resEl.StringResult.Trim().ToUpper();
                if (string.IsNullOrEmpty(nomeEl)) { ed.WriteMessage("  [!] Digite o nome do elemento.\n"); continue; }

                ed.WriteMessage($"  Buscando '{nomeEl}'...");
                System.Collections.Generic.List<System.Collections.Generic.Dictionary<string, object?>> elementos;
                try { elementos = supabase.BuscarElementosPorNomeEPedido(pedidoId, nomeEl); }
                catch (System.Exception ex) { ed.WriteMessage($"\n  [ERRO] {ex.Message}\n  Tente novamente.\n"); continue; }

                if (elementos.Count == 0)
                {
                    ed.WriteMessage($"\n  [!] '{nomeEl}' não encontrado em '{pedidoLocalizador}'. Tente novamente. ESC cancela.\n");
                    continue;
                }

                if (elementos.Count == 1)
                {
                    elementoId = ExtrairString(elementos[0], "id");
                    elementoNome = ExtrairString(elementos[0], "nome");
                    ed.WriteMessage($"\n  [OK] Elemento: {elementoNome}");
                    break;
                }

                ed.WriteMessage($"\n  {elementos.Count} elementos:");
                for (int i = 0; i < elementos.Count; i++)
                    ed.WriteMessage($"\n  [{i + 1}] {ExtrairString(elementos[i], "nome")}");

                var optEn = new PromptIntegerOptions($"\n  Escolha [1-{elementos.Count}] ou ESC: ") { LowerLimit = 1, UpperLimit = elementos.Count };
                var resEn = ed.GetInteger(optEn);
                if (resEn.Status != PromptStatus.OK) { ed.WriteMessage("\n  Redigite o nome.\n"); continue; }

                elementoId = ExtrairString(elementos[resEn.Value - 1], "id");
                elementoNome = ExtrairString(elementos[resEn.Value - 1], "nome");
                ed.WriteMessage($"\n  [OK] Elemento: {elementoNome}");
                break;
            }

            // ── ETAPA 3: Selecionar área ────────────────────────────────────
            ed.WriteMessage($"\n\n  Pedido: {pedidoLocalizador}  |  Elemento: {elementoNome}");
            ed.WriteMessage("\n  Selecione a área (ESC cancela):\n");

            var resPt1 = ed.GetPoint(new PromptPointOptions("\nPrimeiro canto: "));
            if (resPt1.Status != PromptStatus.OK) { ed.WriteMessage("\n[CANCELADO]\n"); return; }

            var resPt2 = ed.GetCorner(new PromptCornerOptions("\nSegundo canto: ", resPt1.Value));
            if (resPt2.Status != PromptStatus.OK) { ed.WriteMessage("\n[CANCELADO]\n"); return; }

            var janela = new Extents2d(
                new Point2d(System.Math.Min(resPt1.Value.X, resPt2.Value.X), System.Math.Min(resPt1.Value.Y, resPt2.Value.Y)),
                new Point2d(System.Math.Max(resPt1.Value.X, resPt2.Value.X), System.Math.Max(resPt1.Value.Y, resPt2.Value.Y))
            );

            // ── ETAPA 4: Exportar + Enviar ──────────────────────────────────
            var nomeArquivo = $"{elementoNome}_CAD_{System.DateTime.Now:yyyyMMdd_HHmmss}.png";
            var tempPath    = System.IO.Path.Combine(System.IO.Path.GetTempPath(), nomeArquivo);

            ed.WriteMessage("\n  Exportando PNG...");
            try
            {
                ExportarPng(doc, db, janela, tempPath);
                ed.WriteMessage(" OK");
            }
            catch (System.Exception ex)
            {
                ed.WriteMessage($"\n[ERRO] PNG: {ex.Message}\n  Dica: rode PCP_DIAG para ver plotters disponíveis.\n");
                return;
            }

            ed.WriteMessage("\n  Enviando para o PCP...");
            try
            {
                var bytes      = System.IO.File.ReadAllBytes(tempPath);
                var urlPublica = supabase.UploadPng(elementoId, nomeArquivo, bytes);
                ed.WriteMessage(" upload OK");
                supabase.RegistrarArquivoElemento(elementoId, nomeArquivo, urlPublica, bytes.LongLength);
                ed.WriteMessage(" registrado OK");
            }
            catch (System.Exception ex)
            {
                ed.WriteMessage($"\n[ERRO] Envio: {ex.Message}\n");
                return;
            }
            finally
            {
                try { if (System.IO.File.Exists(tempPath)) System.IO.File.Delete(tempPath); } catch { }
            }

            ed.WriteMessage($"\n\n[CONCLUÍDO] '{elementoNome}' já aparece no app PCP → {pedidoLocalizador}.\n");
        }

        // ═══════════════════════════════════════════════════════════════════
        // PlotEngine — exporta a janela como PNG
        // ATENÇÃO: a transaction deve ser fechada ANTES de rodar o PlotEngine
        // ═══════════════════════════════════════════════════════════════════
        private static void ExportarPng(Document doc, Database db, Extents2d janela, string outputPath)
        {
            // ── Passo 1: Pegar layoutId em uma transaction curta, depois FECHAR ──
            // PlotEngine e transactions abertas são incompatíveis no AutoCAD
            ObjectId layoutId;
            using (var tr = db.TransactionManager.StartTransaction())
            {
                var layoutDict = (DBDictionary)tr.GetObject(db.LayoutDictionaryId, OpenMode.ForRead);
                layoutId = ObjectId.Null;
                foreach (DBDictionaryEntry entry in layoutDict)
                {
                    var lo = (Layout)tr.GetObject(entry.Value, OpenMode.ForRead);
                    if (lo.ModelType) { layoutId = entry.Value; break; }
                }
                tr.Commit(); // ← transaction fechada ANTES do plot
            }

            if (layoutId.IsNull)
                throw new System.Exception("Model space não encontrado no drawing.");

            // ── Passo 2: Configurar PlotSettings (SEM transaction aberta) ──
            // CRÍTICO: WorkingDatabase deve estar setado para PlotSettingsValidator funcionar
            HostApplicationServices.WorkingDatabase = db;
            var ps  = new PlotSettings(true); // true = model space
            var psv = PlotSettingsValidator.Current;

            // Tentar media names explícitos — sem string vazia (causa eInvalidInput)
            var tentativas = new[]
            {
                ("PublishToWeb PNG.pc3",              "1024.00 x 768.00 Pixels"),
                ("PublishToWeb PNG.pc3",              "2048.00 x 1536.00 Pixels"),
                ("PublishToWeb PNG.pc3",              "640.00 x 480.00 Pixels"),
                ("PublishToWeb PNG (Transparent).pc3","1024.00 x 768.00 Pixels"),
            };

            bool plotterOk = false;
            foreach (var (dev, media) in tentativas)
            {
                try
                {
                    psv.SetPlotConfigurationName(ps, dev, media);
                    plotterOk = true;
                    break;
                }
                catch { /* tenta próximo */ }
            }

            if (!plotterOk)
                throw new System.Exception(
                    "Plotter PNG não configurado. " +
                    "Verifique o resultado do PCP_DIAG para o nome exato do media.");

            psv.SetPlotWindowArea(ps, janela);
            psv.SetPlotType(ps, Autodesk.AutoCAD.DatabaseServices.PlotType.Window);
            psv.SetUseStandardScale(ps, true);
            psv.SetStdScaleType(ps, StdScaleType.ScaleToFit);
            psv.SetPlotCentered(ps, true);
            psv.SetPlotRotation(ps, PlotRotation.Degrees000);
            try { psv.SetCurrentStyleSheet(ps, "monochrome.ctb"); } catch { }

            var plotInfo = new PlotInfo { Layout = layoutId, OverrideSettings = ps };
            new PlotInfoValidator { MediaMatchingPolicy = MatchingPolicy.MatchEnabled }.Validate(plotInfo);

            // ── Passo 3: Plotar ──
            if (PlotFactory.ProcessPlotState != ProcessPlotState.NotPlotting)
                throw new System.InvalidOperationException("AutoCAD está plotando. Tente novamente.");

            using var engine = PlotFactory.CreatePublishEngine();
            engine.BeginPlot(null, null);
            engine.BeginDocument(plotInfo, doc.Name, null, 1, true, outputPath);
            engine.BeginPage(new PlotPageInfo(), plotInfo, true, null);
            engine.BeginGenerateGraphics(null);
            engine.EndGenerateGraphics(null);
            engine.EndPage(null);
            engine.EndDocument(null);
            engine.EndPlot(null);
        }


        private static string ExtrairString(System.Collections.Generic.Dictionary<string, object?> dict, string key)
        {
            if (!dict.TryGetValue(key, out var val)) return "";
            if (val is JsonElement je) return je.ToString();
            return val?.ToString() ?? "";
        }
    }
}
