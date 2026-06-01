using Autodesk.AutoCAD.Runtime;
using Autodesk.AutoCAD.ApplicationServices.Core;

[assembly: ExtensionApplication(typeof(PcpPlugin.Plugin))]

namespace PcpPlugin
{
    /// <summary>
    /// Entry point do plugin PCP para AutoCAD.
    /// Carregado automaticamente via bundle ou NETLOAD.
    /// </summary>
    public class Plugin : IExtensionApplication
    {
        public void Initialize()
        {
#if !NET8_0_OR_GREATER
            // No .NET Framework 4.8, o CLR não busca deps na pasta do plugin automaticamente.
            // Este handler resolve assemblies (ex: System.Text.Json) a partir do diretório do plugin.
            AppDomain.CurrentDomain.AssemblyResolve += (sender, args) =>
            {
                try
                {
                    var nome = new System.Reflection.AssemblyName(args.Name).Name;
                    var dir = System.IO.Path.GetDirectoryName(
                        System.Reflection.Assembly.GetExecutingAssembly().Location)!;
                    var dll = System.IO.Path.Combine(dir, nome + ".dll");
                    return System.IO.File.Exists(dll)
                        ? System.Reflection.Assembly.LoadFrom(dll)
                        : null;
                }
                catch { return null; }
            };
#endif

            try
            {
                // Carregar configuração salva (URL + Key do Supabase PCP)
                Servicos.ConfigService.Carregar();

                var doc = Application.DocumentManager?.MdiActiveDocument;
                if (doc != null)
                {
                    doc.Editor.WriteMessage("\n======================================");
                    doc.Editor.WriteMessage("\n   PCP Plugin v1.0 - Carregado!      ");
                    doc.Editor.WriteMessage("\n   PCP_IMG — exportar área p/ PCP    ");
                    doc.Editor.WriteMessage("\n======================================\n");
                }
            }
            catch
            {
                // Silencioso — não travar o AutoCAD se algo falhar na inicialização
            }
        }

        public void Terminate()
        {
            // Cleanup se necessário
        }
    }
}
