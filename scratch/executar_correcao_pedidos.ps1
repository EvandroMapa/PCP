$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
    'Content-Type'  = 'application/json'
    'Prefer'        = 'return=representation'
}

$stepEntregues = 'tn52LXmuMwqETFbLqyvMCLxUH'

Write-Host "--- APLICANDO CORRECAO NO SUPABASE ---" -ForegroundColor Cyan

# 1. Corrigir LIVING-MA.127 - 27028
$bodyLiving = @{
    'step_id' = $stepEntregues
} | ConvertTo-Json

$resLiving = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?id=eq.z1BUZEy10V9nE1oVYOS2Y8Lqi" -Method Patch -Headers $headers -Body $bodyLiving
Write-Host "Pedido LIVING-MA.127 - 27028 atualizado para ENTREGUES com sucesso!" -ForegroundColor Green
Write-Host "  Novo step_id no banco: $($resLiving.step_id)"

# 2. Corrigir EDU-JESSE.002 - 26760
$bodyEdu = @{
    'step_id' = $stepEntregues
} | ConvertTo-Json

$resEdu = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?id=eq.arLw7pnErWa9U1qWOr81bLaas" -Method Patch -Headers $headers -Body $bodyEdu
Write-Host "Pedido EDU-JESSE.002 - 26760 atualizado para ENTREGUES com sucesso!" -ForegroundColor Green
Write-Host "  Novo step_id no banco: $($resEdu.step_id)"

# 3. Registrar no audit_logs para manter rastreabilidade total
$auditLiving = @{
    'usuario_id'     = 'sistema'
    'usuario_nome'   = 'Sistema (Correcao de Sincronia)'
    'acao'           = 'mover_etapa'
    'modulo'         = 'pedido'
    'entidade_id'    = 'z1BUZEy10V9nE1oVYOS2Y8Lqi'
    'entidade_label' = 'LIVING-MA.127 - 27028'
    'detalhes'       = @{
        'motivo' = 'Correcao de sincronia de step_id com historico de 01/07'
        'de'     = 'EM ROTA DE ENTREGA'
        'para'   = 'ENTREGUES'
    }
    'dispositivo'    = 'Backend / Script'
} | ConvertTo-Json

Invoke-RestMethod -Uri "$url/rest/v1/audit_logs" -Method Post -Headers $headers -Body $auditLiving

$auditEdu = @{
    'usuario_id'     = 'sistema'
    'usuario_nome'   = 'Sistema (Correcao de Sincronia)'
    'acao'           = 'mover_etapa'
    'modulo'         = 'pedido'
    'entidade_id'    = 'arLw7pnErWa9U1qWOr81bLaas'
    'entidade_label' = 'EDU-JESSE.002 - 26760'
    'detalhes'       = @{
        'motivo' = 'Correcao de sincronia de step_id com historico de 17/08'
        'de'     = 'EXPEDIÇÃO'
        'para'   = 'ENTREGUES'
    }
    'dispositivo'    = 'Backend / Script'
} | ConvertTo-Json

Invoke-RestMethod -Uri "$url/rest/v1/audit_logs" -Method Post -Headers $headers -Body $auditEdu

Write-Host "`nLogs de auditoria inseridos com sucesso!" -ForegroundColor Green
