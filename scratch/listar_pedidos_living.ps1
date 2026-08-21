$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$steps = Invoke-RestMethod -Uri "$url/rest/v1/steps?select=id,name,index" -Headers $headers
$stepMap = @{}
foreach ($s in $steps) { $stepMap[$s.id] = $s.name }

Write-Host "--- TODOS OS PEDIDOS LIVING ---" -ForegroundColor Cyan
$peds = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?localizador=ilike.*LIVING*&select=id,localizador,step_id,is_archived,created_at,delivery_at" -Headers $headers

foreach ($p in $peds) {
    $stepNome = if ($stepMap.ContainsKey($p.step_id)) { $stepMap[$p.step_id] } else { $p.step_id }
    Write-Host "ID: $($p.id) | Localizador: $($p.localizador) | Step: $stepNome | Archived: $($p.is_archived)"
}
