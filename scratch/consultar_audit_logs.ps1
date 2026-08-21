$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$id = 'z1BUZEy10V9nE1oVYOS2Y8Lqi'

Write-Host "--- AUDIT LOGS DO PEDIDO ---" -ForegroundColor Cyan
try {
    $logs = Invoke-RestMethod -Uri "$url/rest/v1/audit_logs?entidade_id=eq.$id&select=*&order=created_at.desc" -Headers $headers
    Write-Host "Encontrados $($logs.Count) logs para o ID do pedido."
    $logs | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Erro: $_"
}

Write-Host "`n--- AUDIT LOGS POR LABEL (27028) ---" -ForegroundColor Cyan
try {
    $logs2 = Invoke-RestMethod -Uri "$url/rest/v1/audit_logs?entidade_label=ilike.*27028*&select=*&order=created_at.desc" -Headers $headers
    Write-Host "Encontrados $($logs2.Count) logs para label 27028."
    $logs2 | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Erro: $_"
}

Write-Host "`n--- ULTIMOS 20 AUDIT LOGS DO SISTEMA ---" -ForegroundColor Cyan
try {
    $recentLogs = Invoke-RestMethod -Uri "$url/rest/v1/audit_logs?select=*&order=created_at.desc&limit=20" -Headers $headers
    foreach ($rl in $recentLogs) {
        Write-Host "[$($rl.created_at)] $($rl.acao) | Modulo: $($rl.modulo) | Entidade: $($rl.entidade_label) ($($rl.entidade_id)) | Usuario: $($rl.usuario_nome) | Detalhes: $($rl.detalhes | ConvertTo-Json -Compress)"
    }
} catch {
    Write-Host "Erro: $_"
}
