$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

function Format-EpochMs($epochMs) {
    if (-not $epochMs) { return "N/A" }
    try {
        $dt = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$epochMs).ToLocalTime()
        return $dt.ToString("dd/MM/yyyy HH:mm:ss")
    } catch {
        return "$epochMs"
    }
}

Write-Host "--- ETAPAS CADASTRADAS (tabela steps / kanban) ---" -ForegroundColor Cyan
$steps = Invoke-RestMethod -Uri "$url/rest/v1/steps?select=*" -Headers $headers
$stepMap = @{}
foreach ($s in $steps) {
    $stepMap[$s.id] = $s.name
    Write-Host "Step ID: $($s.id) | Nome: $($s.name) | Order/Index: $($s.index) | is_archived: $($s.is_archived)"
}

Write-Host "`n--- DADOS DO PEDIDO 27028 ---" -ForegroundColor Cyan
$pedidos = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?localizador=ilike.*27028*&select=*" -Headers $headers

foreach ($p in $pedidos) {
    Write-Host "PEDIDO: $($p.localizador) (ID: $($p.id))"
    $stepNome = if ($stepMap.ContainsKey($p.step_id)) { $stepMap[$p.step_id] } else { "DESCONHECIDO ($($p.step_id))" }
    Write-Host "Step Atual: $stepNome (ID: $($p.step_id))" -ForegroundColor Yellow
    Write-Host "Status: $($p.status)"
    Write-Host "Romaneio: $($p.romaneio | ConvertTo-Json -Compress)"
    
    Write-Host "`nTODOS OS HISTORICOS DO PEDIDO:" -ForegroundColor Green
    $hList = $p.histories
    foreach ($h in $hList) {
        $dataStr = Format-EpochMs $h.createdAt
        $tipo = switch ($h.type) {
            0 { "STATUS" }
            1 { "ETAPA" }
            2 { "TAG" }
            3 { "COMENTARIO" }
            4 { "ARQUIVO" }
            5 { "CRIACAO" }
            6 { "ROMANEIO" }
            default { "TIPO $($h.type)" }
        }
        $userName = if ($h.usuario) { $h.usuario.nome } else { "Sistema/Desconhecido" }
        $userId = if ($h.usuario) { $h.usuario.id } else { "" }
        
        $detalhes = ""
        if ($h.data) {
            if ($h.data.name) { $detalhes = $h.data.name }
            elseif ($h.data.status -ne $null) { $detalhes = "Status: $($h.data.status)" }
            else { $detalhes = ($h.data | ConvertTo-Json -Compress) }
        }
        
        Write-Host "[$dataStr] Tipo: $tipo | Acao: $($h.action) | Dado: $detalhes | Usuario: $userName ($userId)"
    }
}
