$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
    'Content-Type'  = 'application/json'
    'Prefer'        = 'return=minimal'
}

# Corrigir bitola whffv3RcNpNM05VLXaSXA7W5q (EDIR-SO.053)
$bitolaId = 'whffv3RcNpNM05VLXaSXA7W5q'
$pedidoId = 'JZzuk2HQl19qNklnH0LPmnT47'

$body = @{
    'status'            = 'separado'
    'materia_prima_raw' = $null
    'statusess_raw'     = @(
        @{
            'id'        = "${bitolaId}_sep"
            'status'    = 'separado'
            'createdAt' = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        }
    )
} | ConvertTo-Json

$res = Invoke-RestMethod -Uri "$url/rest/v1/pedido_bitolas?id=eq.$bitolaId" -Method Patch -Headers $headers -Body $body
Write-Host "Bitola $bitolaId resetada para 'separado'!" -ForegroundColor Green

# Atualizar status do pedido no Supabase
# Bitolas do pedido EDIR-SO.053:
# 6.3mm -> pronto
# 8.0mm -> separado
# 5.0mm -> separado
# Status do pedido = produzindoCD (porque 6.3mm ja esta pronto)
$bodyPed = @{
    'status' = 'produzindoCD'
} | ConvertTo-Json

$resPed = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?id=eq.$pedidoId" -Method Patch -Headers $headers -Body $bodyPed
Write-Host "Status do pedido $pedidoId sincronizado!" -ForegroundColor Green
