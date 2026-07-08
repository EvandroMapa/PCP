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
        // Log em arquivo para diagnóstico — WriteMessage do AutoCAD 2025 pode falhar silenciosamente
        private static readonly string _logPath = System.IO.Path.Combine(
            System.IO.Path.GetTempPath(), "pcp_plugin_log.txt");

        private static void Log(Editor? ed, string msg)
        {
            var linha = $"[{System.DateTime.Now:HH:mm:ss.fff}] {msg}";
            try { System.IO.File.AppendAllText(_logPath, linha + "\n"); } catch { }
            try { ed?.WriteMessage("\n" + msg); } catch { }
        }

        // ═══════════════════════════════════════════════════════════════════

        // PCP_DIAG — diagnóstico de plotters disponíveis
        // ═══════════════════════════════════════════════════════════════════
        [CommandMethod("PCP_DIAG", CommandFlags.Modal)]
        public void PcpDiag()
        {
            var doc = Application.DocumentManager.MdiActiveDocument;
            var ed  = doc.Editor;

            // Limpar log anterior
            try { System.IO.File.WriteAllText(_logPath, ""); } catch { }

            Log(ed, "=== PCP_DIAG - Diagnostico de Plot ===");

            try
            {
                var db  = doc.Database;
                var psv = PlotSettingsValidator.Current;
                HostApplicationServices.WorkingDatabase = db;

                Log(ed, $"WorkingDatabase: {db.Filename}");

                // Listar TODOS os plotters disponíveis
                var ps = new PlotSettings(true);
                psv.RefreshLists(ps);
                var plotters = psv.GetPlotDeviceList();

                Log(ed, $"Total de plotters: {plotters.Count}");
                foreach (string plotter in plotters)
                {
                    Log(ed, $"  Plotter: '{plotter}'");

                    // Para cada plotter, listar os media names
                    if (plotter.IndexOf("PNG", System.StringComparison.OrdinalIgnoreCase) >= 0 ||
                        plotter.IndexOf("JPG", System.StringComparison.OrdinalIgnoreCase) >= 0 ||
                        plotter.IndexOf("JPEG", System.StringComparison.OrdinalIgnoreCase) >= 0 ||
                        plotter.IndexOf("BMP", System.StringComparison.OrdinalIgnoreCase) >= 0 ||
                        plotter.IndexOf("TIFF", System.StringComparison.OrdinalIgnoreCase) >= 0 ||
                        plotter.IndexOf("PDF", System.StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        try
                        {
                            var psTemp = new PlotSettings(true);
                            psv.SetPlotConfigurationName(psTemp, plotter, null);
                            var mediaNames = psv.GetCanonicalMediaNameList(psTemp);
                            Log(ed, $"    -> {mediaNames.Count} media(s):");
                            foreach (string media in mediaNames)
                            {
                                var local = psv.GetLocaleMediaName(psTemp, media);
                                Log(ed, $"      canonical='{media}' locale='{local}'");
                            }
                        }
                        catch (System.Exception ex)
                        {
                            Log(ed, $"    -> ERRO ao listar medias: {ex.Message}");
                        }
                    }
                }

                Log(ed, "=== Fim do diagnostico ===");
                Log(ed, $"Log salvo em: {_logPath}");
            }
            catch (System.Exception ex)
            {
                Log(ed, $"[ERRO FATAL PCP_DIAG] {ex.GetType().Name}: {ex.Message}");
                Log(ed, $"StackTrace: {ex.StackTrace}");
            }
        }


        // ═══════════════════════════════════════════════════════════════════
        // PCP_IMG — exportar imagem para elemento
        // ═══════════════════════════════════════════════════════════════════
        [CommandMethod("PCP_IMG", CommandFlags.Modal)]
        public void PcpImg()
        {
            var doc      = Application.DocumentManager.MdiActiveDocument;
            var ed       = doc.Editor;

            try
            {
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
                Log(ed, $"Pedido: {pedidoLocalizador}  |  Elemento: {elementoNome}");
                Log(ed, "Selecione a area (ESC cancela):");

                var resPt1 = ed.GetPoint(new PromptPointOptions("\nPrimeiro canto: "));
                if (resPt1.Status != PromptStatus.OK) { Log(ed, "[CANCELADO]"); return; }

                var resPt2 = ed.GetCorner(new PromptCornerOptions("\nSegundo canto: ", resPt1.Value));
                if (resPt2.Status != PromptStatus.OK) { Log(ed, "[CANCELADO]"); return; }

                Log(ed, "Segundo canto OK - construindo janela...");

                var janela = new Extents2d(
                    new Point2d(System.Math.Min(resPt1.Value.X, resPt2.Value.X), System.Math.Min(resPt1.Value.Y, resPt2.Value.Y)),
                    new Point2d(System.Math.Max(resPt1.Value.X, resPt2.Value.X), System.Math.Max(resPt1.Value.Y, resPt2.Value.Y))
                );

                Log(ed, $"Janela OK: ({janela.MinPoint.X:F2}, {janela.MinPoint.Y:F2}) a ({janela.MaxPoint.X:F2}, {janela.MaxPoint.Y:F2})");

                // ── ETAPA 4: Exportar + Enviar ──────────────────────────────────
                var nomeArquivo = SanitizarNome($"{elementoNome}_CAD_{System.DateTime.Now:yyyyMMdd_HHmmss}.png");
                var tempPath    = System.IO.Path.Combine(System.IO.Path.GetTempPath(), nomeArquivo);

                Log(ed, $"[4a] Exportando PNG para: {tempPath}");
                try
                {
                    ExportarPng(doc, db, janela, tempPath);
                    Log(ed, "[4a] PNG exportado OK");
                }
                catch (System.Exception ex)
                {
                    Log(ed, $"[ERRO 4a] PNG falhou: {ex.GetType().Name}: {ex.Message}");
                    Log(ed, $"StackTrace: {ex.StackTrace}");
                    return;
                }

                // Verificar se o arquivo foi criado
                if (!System.IO.File.Exists(tempPath))
                {
                    Log(ed, $"[ERRO] Arquivo PNG nao foi criado em: {tempPath}");
                    return;
                }

                var bytes = System.IO.File.ReadAllBytes(tempPath);
                Log(ed, $"[4b] Arquivo PNG: {bytes.Length} bytes");

                Log(ed, "[4c] Enviando upload para Supabase Storage...");
                string urlPublica;
                try
                {
                    urlPublica = supabase.UploadPng(elementoId, nomeArquivo, bytes);
                    Log(ed, $"[4c] Upload OK: {urlPublica}");
                }
                catch (System.Exception ex)
                {
                    Log(ed, $"[ERRO 4c] Upload falhou: {ex.GetType().Name}: {ex.Message}");
                    return;
                }

                Log(ed, "[4d] Registrando na tabela elemento_arquivos...");
                try
                {
                    supabase.RegistrarArquivoElemento(elementoId, nomeArquivo, urlPublica, bytes.LongLength);
                    Log(ed, "[4d] Registro OK");
                }
                catch (System.Exception ex)
                {
                    Log(ed, $"[ERRO 4d] Registro falhou: {ex.GetType().Name}: {ex.Message}");
                    return;
                }

                // Limpar temp
                try { if (System.IO.File.Exists(tempPath)) System.IO.File.Delete(tempPath); } catch { }

                Log(ed, $"[CONCLUIDO] '{elementoNome}' ja aparece no app PCP: {pedidoLocalizador}");
            }
            catch (System.Exception ex)
            {
                Log(ed, $"[ERRO FATAL PCP_IMG] {ex.GetType().Name}: {ex.Message}");
                Log(ed, $"StackTrace: {ex.StackTrace}");
            }
            catch
            {
                Log(ed, "[ERRO FATAL PCP_IMG] Excecao nao-managed capturada");
            }
        }

        // ═══════════════════════════════════════════════════════════════════
        // ExportarPng — Zoom + CapturePreviewImage (síncrono, sem PlotEngine)
        // ═══════════════════════════════════════════════════════════════════
        private void ExportarPng(Document doc, Database db, Extents2d janela, string outputPath)
        {
            var ed = doc.Editor;

            // Salvar view atual para restaurar depois
            var savedView = (ViewTableRecord)ed.GetCurrentView().Clone();

            try
            {
                // Zoom na janela selecionada via comando (garante renderização)
                var minPt = janela.MinPoint;
                var maxPt = janela.MaxPoint;

                ed.Command("_.ZOOM", "_W",
                    new Point3d(minPt.X, minPt.Y, 0),
                    new Point3d(maxPt.X, maxPt.Y, 0));

                // Forçar regeneração para garantir que o viewport atualizou
                ed.Command("_.REGEN");

                // CapturePreviewImage — síncrono, captura o viewport atual
                uint largura = 1920;
                uint altura = 1080;
                // Manter proporção da janela selecionada
                double proporcao = (maxPt.X - minPt.X) / (maxPt.Y - minPt.Y);
                if (proporcao > 1.0)
                    altura = (uint)(largura / proporcao);
                else
                    largura = (uint)(altura * proporcao);

                var bitmap = doc.CapturePreviewImage(largura, altura);
                if (bitmap != null)
                {
                    bitmap.Save(outputPath, System.Drawing.Imaging.ImageFormat.Png);
                    bitmap.Dispose();
                }
                else
                {
                    throw new System.Exception("CapturePreviewImage retornou null");
                }
            }
            finally
            {
                // Restaurar view original
                ed.SetCurrentView(savedView);
            }
        }


        /// <summary>
        /// Remove acentos e caracteres especiais do nome de arquivo.
        /// Mesma lógica do Flutter (SupabaseStorageService._sanitizeFileName).
        /// </summary>
        private static string SanitizarNome(string nome)
        {
            const string de = "àáâãäåæçèéêëìíîïðñòóôõöùúûüýÿÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖÙÚÛÜÝ";
            const string para = "aaaaaaaceeeeiiiidnoooooouuuuyyAAAAAAAECEEEEIIIIDNOOOOOUUUUY";
            var resultado = nome;
            for (int i = 0; i < de.Length; i++)
                resultado = resultado.Replace(de[i], para[i]);
            // Remove qualquer caractere que não seja letra, número, ponto, hífen ou underscore
            resultado = System.Text.RegularExpressions.Regex.Replace(resultado, @"[^\w.\-]", "_");
            return resultado;
        }

        private static string ExtrairString(System.Collections.Generic.Dictionary<string, object?> dict, string key)
        {
            if (!dict.TryGetValue(key, out var val)) return "";
            if (val is JsonElement je) return je.ToString();
            return val?.ToString() ?? "";
        }
    }
}
