$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

Write-Host "--- PEDIDOS EM ROTA DE ENTREGA (uFJ3S0dZmctuzEkImApVs58JD) ---" -ForegroundColor Cyan
$emRota = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?step_id=eq.uFJ3S0dZmctuzEkImApVs58JD&is_archived=eq.false&select=id,localizador,step_id,is_archived,created_at,delivery_at" -Headers $headers
foreach ($p in $emRota) {
    Write-Host "ID: $($p.id) | Localizador: $($p.localizador) | Created: $($p.created_at) | Delivery: $($p.delivery_at)"
}

Write-Host "`n--- PEDIDOS EM ENTREGUES (tn52LXmuMwqETFbLqyvMCLxUH) ---" -ForegroundColor Cyan
$entregues = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?step_id=eq.tn52LXmuMwqETFbLqyvMCLxUH&is_archived=eq.false&select=id,localizador,step_id,is_archived,created_at,delivery_at" -Headers $headers
foreach ($p in $entregues) {
    Write-Host "ID: $($p.id) | Localizador: $($p.localizador) | Created: $($p.created_at) | Delivery: $($p.delivery_at)"
}
