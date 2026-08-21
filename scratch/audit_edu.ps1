$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$body = [System.Text.Encoding]::UTF8.GetBytes((@{
    'usuario_id'     = 'sistema'
    'usuario_nome'   = 'Sistema (Correcao de Sincronia)'
    'acao'           = 'mover_etapa'
    'modulo'         = 'pedido'
    'entidade_id'    = 'arLw7pnErWa9U1qWOr81bLaas'
    'entidade_label' = 'EDU-JESSE.002 - 26760'
    'detalhes'       = @{
        'motivo' = 'Correcao de sincronia de step_id com historico de 17/08'
        'de'     = 'EXPEDICAO'
        'para'   = 'ENTREGUES'
    }
    'dispositivo'    = 'Backend / Script'
} | ConvertTo-Json))

$res = Invoke-RestMethod -Uri "$url/rest/v1/audit_logs" -Method Post -Headers $headers -ContentType "application/json; charset=utf-8" -Body $body
Write-Host "Audit log registrado com sucesso!" -ForegroundColor Green
