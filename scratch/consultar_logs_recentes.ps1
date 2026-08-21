$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$id = 'z1BUZEy10V9nE1oVYOS2Y8Lqi'

Write-Host "--- TODOS OS LOGS DO PEDIDO 27028 ---" -ForegroundColor Cyan
$logs = Invoke-RestMethod -Uri "$url/rest/v1/audit_logs?or=(entidade_id.eq.$id,entidade_label.ilike.*27028*)&select=*&order=created_at.asc" -Headers $headers

foreach ($l in $logs) {
    Write-Host "[$($l.created_at)] $($l.acao) | Por: $($l.usuario_nome) | Detalhes: $($l.detalhes | ConvertTo-Json -Compress)"
}

Write-Host "`n--- TODOS OS LOGS DE HOJE E ONTEM ---" -ForegroundColor Cyan
$recent = Invoke-RestMethod -Uri "$url/rest/v1/audit_logs?created_at=gte.2026-08-20T00:00:00Z&select=*&order=created_at.asc" -Headers $headers
foreach ($r in $recent) {
    Write-Host "[$($r.created_at)] $($r.acao) | Modulo: $($r.modulo) | Entidade: $($r.entidade_label) ($($r.entidade_id)) | Usuario: $($r.usuario_nome) | Detalhes: $($r.detalhes | ConvertTo-Json -Compress)"
}
