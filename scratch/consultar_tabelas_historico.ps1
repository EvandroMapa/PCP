$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$id = 'z1BUZEy10V9nE1oVYOS2Y8Lqi'

Write-Host "--- PEDIDO_STEPS_HISTORY ---" -ForegroundColor Cyan
try {
    $stepsHist = Invoke-RestMethod -Uri "$url/rest/v1/pedido_steps_history?pedido_id=eq.$id&select=*" -Headers $headers
    $stepsHist | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Erro: $_"
}

Write-Host "`n--- PEDIDO_STATUS_HISTORY ---" -ForegroundColor Cyan
try {
    $statusHist = Invoke-RestMethod -Uri "$url/rest/v1/pedido_status_history?pedido_id=eq.$id&select=*" -Headers $headers
    $statusHist | ConvertTo-Json -Depth 5
} catch {
    Write-Host "Erro: $_"
}
