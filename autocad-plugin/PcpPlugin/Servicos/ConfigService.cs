using System.Text.Json;

namespace PcpPlugin.Servicos
{
    /// <summary>
    /// Gerencia configuração do PcpPlugin (URL e Key do Supabase PCP).
    /// Salva em arquivo local na pasta do usuário.
    /// </summary>
    public static class ConfigService
    {
        private static readonly string _configPath = System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "PcpPlugin",
            "config.json"
        );

        // Credenciais do Supabase PCP
        public static string SupabaseUrl { get; set; } = "https://aumfedyfrxuwgkdhwrel.supabase.co";
        public static string SupabaseKey { get; set; } = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8";

        /// <summary>
        /// Carrega configuração do disco, ou usa valores padrão.
        /// </summary>
        public static void Carregar()
        {
            try
            {
                if (System.IO.File.Exists(_configPath))
                {
                    var json = System.IO.File.ReadAllText(_configPath);
                    var config = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
                    if (config != null)
                    {
                        if (config.TryGetValue("url", out var url)) SupabaseUrl = url;
                        if (config.TryGetValue("key", out var key)) SupabaseKey = key;
                    }
                }
            }
            catch
            {
                // Usa valores padrão se der erro
            }
        }

        /// <summary>
        /// Salva configuração atual no disco.
        /// </summary>
        public static void Salvar()
        {
            try
            {
                var dir = System.IO.Path.GetDirectoryName(_configPath)!;
                System.IO.Directory.CreateDirectory(dir);

                var config = new Dictionary<string, string>
                {
                    ["url"] = SupabaseUrl,
                    ["key"] = SupabaseKey,
                };
                var json = JsonSerializer.Serialize(config, new JsonSerializerOptions { WriteIndented = true });
                System.IO.File.WriteAllText(_configPath, json);
            }
            catch
            {
                // Silencioso
            }
        }
    }
}
