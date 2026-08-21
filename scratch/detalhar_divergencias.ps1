$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$pedidos = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?id=in.(arLw7pnErWa9U1qWOr81bLaas,z1BUZEy10V9nE1oVYOS2Y8Lqi,9KH4XEbelxpOEI0hOjiVQEVuA,UYnZUPB6gYNX9g7Zg1Irgh8hu,sRGZUnT0SJMd6xqT9Q2hp7VHd)&select=id,localizador,step_id,is_archived,histories" -Headers $headers

foreach ($p in $pedidos) {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "PEDIDO: $($p.localizador) (ID: $($p.id))"
    Write-Host "step_id no banco: $($p.step_id)"
    Write-Host "is_archived: $($p.is_archived)"
    if ($p.histories) {
        $stepHist = $p.histories | Where-Object { $_.type -eq 1 }
        foreach ($sh in $stepHist) {
            $dt = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$sh.createdAt).ToLocalTime().ToString("dd/MM/yyyy HH:mm")
            Write-Host "  [$dt] $($sh.data.name) (ID: $($sh.data.id)) - Por: $($sh.usuario.nome)"
        }
    }
}
