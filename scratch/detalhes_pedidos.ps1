$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$pedidos = @(
    @{ id = 'qPWJCbUg55XxfRCQgX13xpsaY'; loc = 'KENNETH.026 - 26349' },
    @{ id = 'jUIBwhwF3TG0RCrEuVICCI1Vn'; loc = 'RENATO-LU.003 - 27401' },
    @{ id = 'TpE9gZv6TR47uNAMju2KOXDtU'; loc = 'VICE-PURI.001 - 27460' },
    @{ id = 'baiFRaFIovuaHwraNiPl8eDap'; loc = 'CAIO-N.002 - 27500' }
)

# Buscar bitolas cadastradas (tabela bitolas) para pegar os nomes das bitolas
$bitolasCadastradas = Invoke-RestMethod -Uri "$url/rest/v1/bitolas?select=id,nome,number" -Headers $headers
$bitolaMap = @{}
foreach ($bc in $bitolasCadastradas) { $bitolaMap[$bc.id] = $bc.nome }

# Buscar todas as ordens (não arquivadas e arquivadas recentes)
$ordens = Invoke-RestMethod -Uri "$url/rest/v1/ordens?select=id,localizador,id_pedidos_bitolas,is_archived,created_at,updated_at" -Headers $headers

foreach ($p in $pedidos) {
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "PEDIDO: $($p.loc) [ID: $($p.id)]" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan

    $bitolas = Invoke-RestMethod -Uri "$url/rest/v1/pedido_bitolas?pedido_id=eq.$($p.id)&select=*" -Headers $headers

    foreach ($b in $bitolas) {
        $nomeBitola = if ($bitolaMap.ContainsKey($b.bitola_id)) { $bitolaMap[$b.bitola_id] } else { $b.bitola_id }
        Write-Host "`n  -> BITOLA: $nomeBitola | Qtde: $($b.quantidade) Kg | Status no Banco: $($b.status)" -ForegroundColor Yellow
        Write-Host "     Bitola Item ID: $($b.id)"
        Write-Host "     Statusess RAW: $($b.statusess_raw | ConvertTo-Json -Compress)"
        
        # Procurar em quais ordens essa bitola aparece no id_pedidos_bitolas
        $ordensComEssaBitola = @()
        foreach ($ord in $ordens) {
            $refs = $ord.id_pedidos_bitolas
            if ($refs -ne $null) {
                foreach ($r in $refs) {
                    if ($r.produtoId -eq $b.id -or $r.bitola_id -eq $b.id) {
                        $ordensComEssaBitola += $ord
                    }
                }
            }
        }

        if ($ordensComEssaBitola.Count -gt 0) {
            foreach ($ocb in $ordensComEssaBitola) {
                Write-Host "     [VINCULADA A ORDEM] ID: $($ocb.id) | Localizador: $($ocb.localizador) | is_archived: $($ocb.is_archived)" -ForegroundColor Green
            }
        } else {
            Write-Host "     [SEM ORDEM] Nao encontrada em nenhuma ordem (nem ativa, nem arquivada)" -ForegroundColor Magenta
        }
    }
}
