using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace PcpPlugin.Servicos
{
    /// <summary>
    /// Cliente HTTP SÍNCRONO para a REST API e Storage do Supabase PCP.
    /// Usa chamadas síncronas para evitar deadlock na thread STA do AutoCAD.
    /// </summary>
    public class SupabaseClient
    {
        private readonly HttpClient _http;

        public SupabaseClient()
        {
            _http = new HttpClient();
            _http.DefaultRequestHeaders.Add("apikey", ConfigService.SupabaseKey);
            _http.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", ConfigService.SupabaseKey);
            _http.DefaultRequestHeaders.Add("Prefer", "return=representation");
            _http.Timeout = TimeSpan.FromSeconds(30);
        }

        private string BaseUrl => $"{ConfigService.SupabaseUrl}/rest/v1";
        private string StorageUrl => $"{ConfigService.SupabaseUrl}/storage/v1";

        // ══════════════════════════════════════════════════════
        // REST — LEITURA
        // ══════════════════════════════════════════════════════

        /// <summary>
        /// Busca pedidos cujo localizador contenha o termo informado.
        /// Retorna id, localizador, descricao (até 10 resultados).
        /// </summary>
        public List<Dictionary<string, object?>> BuscarPedidosPorLocalizador(string termo)
        {
            var termoEncoded = Uri.EscapeDataString($"%{termo}%");
            return Get($"pedidos?localizador=ilike.{termoEncoded}&select=id,localizador,descricao&limit=10");
        }

        /// <summary>
        /// Busca elementos pelo nome dentro de um pedido específico.
        /// Retorna id, nome, pedido_id (até 10 resultados).
        /// </summary>
        public List<Dictionary<string, object?>> BuscarElementosPorNomeEPedido(string pedidoId, string nome)
        {
            var nomeEncoded = Uri.EscapeDataString($"%{nome}%");
            return Get($"elementos?pedido_id=eq.{pedidoId}&nome=ilike.{nomeEncoded}&select=id,nome,pedido_id&limit=10");
        }


        // ══════════════════════════════════════════════════════
        // REST — ESCRITA
        // ══════════════════════════════════════════════════════

        /// <summary>
        /// Registra um arquivo na tabela elemento_arquivos.
        /// Retorna o id gerado.
        /// </summary>
        public string RegistrarArquivoElemento(
            string elementoId,
            string nome,
            string url,
            long tamanho,
            string tipo = "image/png",
            string extensao = "png")
        {
            var dados = new Dictionary<string, object?>
            {
                ["elemento_id"] = elementoId,
                ["nome"]        = nome,
                ["url"]         = url,
                ["tamanho"]     = tamanho,
                ["tipo"]        = tipo,
                ["extensao"]    = extensao,
            };
            var resultado = Post("elemento_arquivos", dados);
            return resultado?["id"]?.ToString() ?? "";
        }

        // ══════════════════════════════════════════════════════
        // STORAGE — Upload de arquivo binário
        // ══════════════════════════════════════════════════════

        /// <summary>
        /// Faz upload de um arquivo PNG para o bucket "elementos" do Supabase Storage.
        /// Retorna a URL pública do arquivo.
        /// </summary>
        public string UploadPng(string elementoId, string nomeArquivo, byte[] bytes)
        {
            var path = $"elementos/{elementoId}/{nomeArquivo}";
            var uploadUrl = $"{StorageUrl}/object/{path}";

            // Remove "Prefer" header para upload (não aplicável no Storage)
            using var httpUpload = new HttpClient();
            httpUpload.DefaultRequestHeaders.Add("apikey", ConfigService.SupabaseKey);
            httpUpload.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", ConfigService.SupabaseKey);
            httpUpload.DefaultRequestHeaders.Add("x-upsert", "true");
            httpUpload.Timeout = TimeSpan.FromSeconds(60);

            var content = new ByteArrayContent(bytes);
            content.Headers.ContentType = new MediaTypeHeaderValue("image/png");

            var response = httpUpload.PutAsync(uploadUrl, content).GetAwaiter().GetResult();
            response.EnsureSuccessStatusCode();

            // URL pública
            return $"{ConfigService.SupabaseUrl}/storage/v1/object/public/{path}";
        }

        // ══════════════════════════════════════════════════════
        // HTTP Helpers — 100% SÍNCRONO (evita deadlock no AutoCAD)
        // ══════════════════════════════════════════════════════

        private List<Dictionary<string, object?>> Get(string endpoint)
        {
            var request = new HttpRequestMessage(HttpMethod.Get, $"{BaseUrl}/{endpoint}");
            var response = _http.SendAsync(request).GetAwaiter().GetResult();
            response.EnsureSuccessStatusCode();
            var json = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
            return DeserializeList(json);
        }

        private Dictionary<string, object?>? Post(string endpoint, Dictionary<string, object?> dados)
        {
            var json = JsonSerializer.Serialize(dados);
            var request = new HttpRequestMessage(HttpMethod.Post, $"{BaseUrl}/{endpoint}");
            request.Content = new StringContent(json, Encoding.UTF8, "application/json");
            var response = _http.SendAsync(request).GetAwaiter().GetResult();
            response.EnsureSuccessStatusCode();
            var responseJson = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
            var lista = DeserializeList(responseJson);
            return lista.Count > 0 ? lista[0] : null;
        }

        private static List<Dictionary<string, object?>> DeserializeList(string json)
        {
            var result = new List<Dictionary<string, object?>>();
            using var doc = JsonDocument.Parse(json);

            if (doc.RootElement.ValueKind != JsonValueKind.Array)
                return result;

            foreach (var item in doc.RootElement.EnumerateArray())
            {
                var dict = new Dictionary<string, object?>();
                foreach (var prop in item.EnumerateObject())
                    dict[prop.Name] = prop.Value.Clone();
                result.Add(dict);
            }
            return result;
        }
    }
}
