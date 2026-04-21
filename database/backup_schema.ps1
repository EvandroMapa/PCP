# Script para Backup da Estrutura (Schema) do Supabase
# Necessário: Node.js instalado e projeto vinculado (npx supabase link)

Write-Host "Iniciando Dump da Estrutura do Supabase..." -ForegroundColor Cyan

# Executa o dump do projeto vinculado (--linked)
# O dump salva apenas a estrutura (--schema public) e ignora os dados
npx supabase db dump --linked --schema public -f database/schema.sql

if ($LASTEXITCODE -eq 0) {
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "Backup concluído com sucesso!" -ForegroundColor Green
    Write-Host "Arquivo gerado: database/schema.sql" -ForegroundColor Green
    Write-Host "Não esqueça de fazer o commit deste arquivo." -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
} else {
    Write-Host "------------------------------------------" -ForegroundColor Red
    Write-Host "ERRO ao gerar backup." -ForegroundColor Red
    Write-Host "Certifique-se de que o projeto está vinculado rodando:" -ForegroundColor Yellow
    Write-Host "npx supabase link --project-ref aumfedyfrxuwgkdhwrel" -ForegroundColor Yellow
    Write-Host "------------------------------------------" -ForegroundColor Red
}
